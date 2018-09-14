pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

contract Supplychain{
    //Enum que atribui uma funcao na cadeia para cada usuario de carteira

    //STRUCTURES

    enum Function{

        Nothing, Productor, Stock, Transport, CirurgicCenter, Seller,  Buyer
    }
    //representa um recibo para quem adquiriu um medicamento
    struct Receive{

        string uuid;
        string id;
        uint timestamp;
        address from;
        address to;
    }
    //representa a carteira de uma pessoa ou depósito
    struct Wallet{

        mapping(string => uint) medicines;//tipos de remedios que a carteira possui
        mapping(string => bool) products;//produtos individuais que a carteira possui
        uint maxWeight;
        uint currentWeight;
        Function func; //funcao dessa carteira na cadeia supplychain
    }
   //representa um tipo de medicamento
    struct Medicine{

        string name;
        string description;
        bool initialized;
        uint weigth;
        uint value; //preço
        uint validity;
        /* string[] components; */
    }
    //representa um produto único
    struct Product{

        string id; //Tipo do medicamento
        address owner;//dono corrente
        bool isValid; //esta na validade
        uint creationTime;
        address[] path;
        uint[] timestamps;
    }
    //Produto incompleto que nao pode sair das maos do produtor enquanto nao estiver pronto
    /* struct IncompleteProduct{

      string id;
      address owner;
      string[] components;
    } */
    //representa um possivel sinistro para um produto no meio da cadeia
    struct Sinister{

        string title;
        string description;
        string envolvedProduct; //identificador do produto unico
        address responsible; //quem estava de posse de tal produto
        uint timestamp; //hora
    }

    //STRUCTURES END

    //VARIABLES

    //contract manager
    address public manager;

    //mapeia a id unica do tipo de medicamento para sua respectiva struct
    mapping(string => Medicine)private medicines;

    //mapeia um endereco do dono da carteira a sua respectiva struct descrevendo
    //tudo o que ele tem
    mapping(address => Wallet)private wallets;
    //mapeia um produto unico ao seu tipo de medicamento e seu dono
    mapping(string => Product)private products;
    //mapeia id de um produto verificando se ele existe na cadeia
    mapping(string => bool)private productExist;

    string[]public medicineNames;
    string[]public allProducts;
    //verifica se uma carteira participa ou nao da cadeia
    mapping(address => bool)private participates;
    //Time when contract was deployed
    uint begin;
    //lista de recibos obtidos por um endereço
    mapping(address => Receive[]) receives;
    //lista de sinistros verificados por um endereço
    mapping(address => Sinister[]) sinisters;
    /*mapping que indica se uma carteira está dentro do centro alfa*/
    mapping(address => bool) isInAlfaCenter;
    mapping(string => Function) stringToFunction;

    //VARIABLES END

    /* mapping(string => bool) knownComponent;
    mapping(string => IncompleteProduct) incompleteProducts; */

    //EVENTS
    event medicineCreated(string id); //novo tipo de medicamento criado
    event medicineTransfered(string uuid, string id, address from, address to);//medicamento transerido entre carteiras
    event productGenerated(address by, string uuid, string id);//produto gerado por um produtor
    event changeSent(address to, uint change); //troco enviado
    event medicineBought(address by, address from, string uuid); //produto comprado
    event FunctionDesignated(address to, Function f); //funcao designada
    event ProductOutOfValidity(string uuid, string id, uint time); //produto venceu a validade
    event NewSinister(string title, string uuid, address responsible); //sinistro notificado
    event PathIncremented(string uuid, string id, address adr, uint timestamp); //caminho de um produto incrementado
    //EVENTS END

    //MODIFIERS

    /*somente o administrador pode mexer*/
    modifier onlyManager{
        require(msg.sender == manager, "only manager");
        _;
    }
    /*So alguem com um papel especifico pode chamar a funcao*/
    modifier only(Function f){
        require(wallets[msg.sender].func == f, "This person is not applied here");
        _;
    }
    /*Verifica se um produto existe*/
    modifier productExists(string uuid){
         require(productExist[uuid], "This product does not exist");
        _;
    }
    /*Verifica se uma pessoa detem um produto*/
    modifier productOwner(address a, string uuid){
        string memory message;

        if(msg.sender == a){
            message = "You dont have this product";
        }
        else{
            message = "This person doesnt have this product";
        }

        require(wallets[msg.sender].products[uuid], message);
        _;
    }
    /*Verifica se uma pessoa esta na cadeia*/
    modifier personExists(address a){
        string memory message;

        if(msg.sender == a){
            message = "You are not a participant";
        }
        else{
            message = "This person does not exist";
        }

        require(participates[a], message);
        _;
    }
    /*Verifica se um produto esta na validade*/
    modifier validProduct(string uuid){
        require(products[uuid].isValid, "Only valid producsts here");
        _;
    }
    //modifier que é chamado no inicio de toda transação para verificar se os produtos estao na validade
    modifier checkTime{
        checkValidity();
        _;
    }

    modifier hasCapacityFor(address adr, string id){

      uint maxWeight = wallets[adr].maxWeight;
      uint currentWeight = wallets[adr].currentWeight;
      uint weigth = medicines[id].weigth;

      require(currentWeight + weigth <= maxWeight, "It exceeds capacity");
      _;
    }

    modifier inexistantWallet(address adr){
      require(!participates[adr], "This wallet has already been created");
      _;
    }

    modifier supplychainRule(address from, address to){
      bool[5] memory rules =
      [wallets[from].func == Function.Productor && wallets[to].func == Function.Transport,
      wallets[from].func == Function.Transport && wallets[to].func == Function.Stock,
      wallets[from].func == Function.Stock && wallets[to].func == Function.CirurgicCenter,
      wallets[from].func == Function.Stock && wallets[to].func == Function.Seller,
      wallets[from].func == Function.Seller && wallets[to].func == Function.Buyer];

       bool ok = false;

       for(uint i = 0; i< rules.length; i++){
         if(rules[i]){
           ok = true;
         }
       }
      require(ok, "It does not agree with the supplychain rules");
      _;
    }
    //MODIFIERS END

    //CONSTRUTOR
    constructor()public{
        manager = msg.sender;
        begin = now;
        wallets[msg.sender] = Wallet(100, 0, Function.Productor);
        participates[msg.sender] = true;

        stringToFunction["Nothing"] = Function.Nothing;
        stringToFunction["Productor"] = Function.Productor;
        stringToFunction["Stock"] = Function.Stock;
        stringToFunction["Transport"] = Function.Transport;
        stringToFunction["CirurgicCenter"] = Function.CirurgicCenter;
        stringToFunction["Seller"] = Function.Seller;
        stringToFunction["Buyer"] = Function.Buyer;
    }
    //END OF CONSTRUCTOR

    // function createComponent(string component) onlyManager{
    //   require(knownComponent[component], "This component has already been created");

    //   knownComponent[component] = true;
    // }

   //Funções auxiliares(private)
   //AUXILIAR
   //AUXILIAR

   /*Função que designa uma função para uma carteira*/
   function designateFunction(address wallet, string func)private checkTime{ //Essa funcao nao esta sendo usada

       wallets[wallet].func = stringToFunction[func];
       emit FunctionDesignated(wallet, stringToFunction[func]);
   }

   /*Busca sequencial de um recibo*/
   function searchReceive(address a, string uuid)private view returns(int){

       for(int i = 0; i < int(receives[a].length); i++){
           uint ui = uint(i);
           Receive memory r = receives[a][ui];
           if(compareStrings(r.uuid, uuid)){
               return i;
           }
       }
       return -1;
   }

   /*Transfere um produto de um endereco para outro*/
   function transferOperation(address from, string uuid, address to)private
   supplychainRule(from, to)  returns(Receive){

       uint timestamp = now - begin;
       string memory id = products[uuid].id;

       wallets[from].products[uuid] = false;
       wallets[from].medicines[id] -= 1;

       products[uuid].owner = to;

       wallets[to].products[uuid] = true;
       wallets[to].medicines[id] += 1;

       Receive memory receive = Receive(uuid, id, timestamp, from, to);

       receives[to].push(receive);

       emit medicineTransfered(uuid, id, from, to);

       return receive;
   }

   /*Funcao que retira a posse do medicamento de alguem*/
   function sendMedicine(string uuid)private{

        string memory id = products[uuid].id;

       wallets[msg.sender].products[uuid] = false;
       wallets[msg.sender].medicines[id] -= 1;
   }

   /*Funcao que envia o troco de funcoes payable*/
   function sendChange()private returns(uint){
       uint balance = address(this).balance;
       msg.sender.transfer(balance);

       emit changeSent(msg.sender, balance);

       return balance;
   }

   /*Funcao auxiliar para comparar strings*/
   function compareStrings (string a, string b)private pure returns (bool){
       if(bytes(a).length != bytes(b).length){
           return false;
       }
       else{
           return keccak256(bytes(a)) == keccak256(bytes(b));
       }
  }

  /*Funcao que verifica a validade de cada produto da cadeia*/
  function checkValidity()private{

      for(uint i = 0; i < allProducts.length; i++){

          Product storage product = products[allProducts[i]];

           if(product.isValid){
               uint timestamp = now - product.creationTime;

               if(timestamp >= medicines[product.id].validity){
                    product.isValid = false;
                    emit ProductOutOfValidity(allProducts[i], product.id, timestamp - medicines[product.id].validity);
               }
           }
      }
  }

  /*salva um novo usuário no caminho percorrido pelo produto uuid*/
  function incrementPath(string uuid, address adr)private productExists(uuid){

       uint time = now - begin;

       products[uuid].path.push(adr);
       products[uuid].timestamps.push(time);

       emit PathIncremented(uuid, products[uuid].id, adr, time);
  }

   //END OF AUXILIAR
   //END OF AUXILIAR
   //END OF AUXILIAR

   //Funções transação de interface com usuário
   //TRANSACTIONS
   //TRANSACTIONS
   //TRANSACTIONS
   /*Funcao que apenas cria um tipo de medicamentos para ficar d=*/
   function medicineCreate(string id, string _name, string _description,uint _weigth, uint _value, uint _validity)
   public onlyManager checkTime{
       require(!medicines[id].initialized, "Medicine already exists");

       medicines[id] = Medicine(_name, _description,true, _weigth, _value, _validity);
       medicineNames.push(id);
       wallets[manager].medicines[id] = 0;

       emit medicineCreated(id);
   }

   /*Função que cria uma carteira para um participante*/
   function createWallet(address adr, uint _maxWeight, string f)public onlyManager
    inexistantWallet(adr){

       wallets[adr] = Wallet(_maxWeight, 0, stringToFunction[f]);
       participates[adr] = true;
   }

   /*Funcao que de fato cria um medicamento com um identificador unico naquela categoria de medicamentos identificada por id*/
   function medicineGenerate(string uuid, string id)public only(Function.Productor)
   hasCapacityFor(msg.sender, id) checkTime{
       require(medicines[id].initialized, "medicine does not exist");
       require(!productExist[uuid], "product already generated");


       uint time = now - begin;
       wallets[msg.sender].medicines[id] += 1;
       productExist[uuid] = true;
       wallets[msg.sender].products[uuid] = true;

       address[] memory array;
       uint[] memory times;
       products[uuid] = Product(id, msg.sender, true, time, array, times);

       incrementPath(uuid, msg.sender);
       allProducts.push(uuid);

       emit productGenerated(msg.sender,uuid,id);
   }

   //Funcao que pega uma unidade de medicamento e transfere para outra carteira
   function transfer(string uuid, address to)public
   productExists(uuid) productOwner(msg.sender, uuid)
   hasCapacityFor(to, products[uuid].id)
    checkTime{

       transferOperation(msg.sender, uuid, to);
       incrementPath(uuid, to);
   }

   /*Funcao que serve para um usuario final comprar o medicamento de alguma parte da cadeia*/
   function buyMedicine(address from, string uuid)public payable
   productExists(uuid) productOwner(from, uuid) checkTime
   validProduct(uuid){

       require(msg.value >= medicines[products[uuid].id].value, "Not enough balance");

       sendChange();
       transferOperation(from, uuid, msg.sender);
       emit medicineBought(msg.sender, from, uuid);
   }

   /*Função chamada por um usuário para notificar um sinistro com um produto de sua posse*/
   function notifySinister(string _title, string _description, string _product)public checkTime
   productExists(_product) productOwner(msg.sender, _product) returns(Sinister){

       uint _timestamp = now - begin;
       Sinister memory sinister = Sinister(_title,_description,_product,msg.sender,_timestamp);
       sinisters[msg.sender].push(sinister);

       emit NewSinister(_title, _product, msg.sender);

       return sinister;
   }
   //TRANSACTIONS END
   //TRANSACTIONS END
   //TRANSACTIONS END

   //Funções de acesso para o usuário
   //ACCESS
   //ACCESS
   /*Rastreia u medicamento devolvendo o seu dono atual*/
   function getOwnerof(string uuid)public view returns(address){
       return products[uuid].owner;
   }

   /*Funcao de acesso que devolve um recibo de um produto*/
   function getReceive(string uuid)public view returns(Receive){
       int index = searchReceive(msg.sender, uuid);

       require(index >= 0);
       uint ui = uint(index);
       return receives[msg.sender][ui];
   }

   /*funcao que retorna onde estava um produto uuid dado um horário específico*/
   function trackProduct(string uuid, uint timestamp)public view
    productExists(uuid) returns(address){
      uint currentTime = now - begin;

      require(timestamp <= currentTime, "Please enter a valid time");

      uint[] memory timestamps = products[uuid].timestamps;

      for(uint i = 0; i < timestamps.length - 1; i++){
        if(timestamps[i] <= timestamp && timestamp <= timestamps[i+1]){
          return products[uuid].path[i];
        }
      }
      return products[uuid].owner;
   }
   //ACCESS END
   //ACCESS END
   //ACCESS END

   //Funções de acesso para testes
   //TEST
   //TEST
   //TEST

   function getMedicineName(string id)public view returns(string){
     return medicines[id].name;
   }
   function getMedicineDescription(string id)public view returns(string){
     return medicines[id].description;
   }
   function getMedicineWeight(string id)public view returns(uint){
     return medicines[id].weigth;
   }
   function getMedicineValue(string id)public view returns(uint){
     return medicines[id].value;
   }
   function getMedicineValidity(string id)public view returns(uint){
     return medicines[id].validity;
   }

   function getWalletMedicineQtd(address adr, string id)public view returns(uint){
      return wallets[adr].medicines[id];
   }

   function getWalletFunction(address adr)public view returns(string){

     if(wallets[adr].func == Function.Productor){
       return "Productor";
     }
     else if(wallets[adr].func == Function.Stock){
       return "Stock";
     }
     else if(wallets[adr].func == Function.Transport){
       return "Transport";
     }
     else if(wallets[adr].func == Function.CirurgicCenter){
       return "Cirurgic center";
     }
     else if(wallets[adr].func == Function.Nothing){
       return "Nothing";
     }
     else if(wallets[adr].func == Function.Seller){
       return "Seller";
     }
     else{
       return "Buyer";
     }
   }

   function getWalletWeight(address adr) public view returns(uint){
      return wallets[adr].maxWeight;
   }
   function getWalletCurrentWeight(address adr)public view returns(uint){
      return wallets[adr].currentWeight;
   }

   function walletHasProduct(address adr, string uuid)public view returns(bool){
      return wallets[adr].products[uuid];
   }
   function getProductExist(string uuid)public view returns(bool){
     return productExist[uuid];
   }

   function getProductId(string uuid)public view returns(string){
     return products[uuid].id;
   }
   function getProductOwner(string uuid)public view returns(address){
     return products[uuid].owner;
   }
   function getProductValid(string uuid)public view returns(bool){
     return products[uuid].isValid;
   }
   function getProductCreationTime(string uuid)public view returns(uint){
     return products[uuid].creationTime;
   }
   //TEST END
   //TEST END
   //TEST END
}
