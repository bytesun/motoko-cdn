import Prim "mo:prim";
import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import Result "mo:base/Result";


import Buckets "Buckets";
import Types "./Types";

 

// Container actor holds all created canisters in a canisters array 
// Use of IC management canister with specified Principal "aaaaa-aa" to update the newly 
// created canisters permissions and settings 
//  https://sdk.dfinity.org/docs/interface-spec/index.html#ic-management-canister
shared ({caller = owner}) actor class Container() = this {

 public type canister_id = Principal;
  public type canister_settings = {
    freezing_threshold : ?Nat;
    controllers : ?[Principal];
    memory_allocation : ?Nat;
    compute_allocation : ?Nat;
  };
  public type definite_canister_settings = {
    freezing_threshold : Nat;
    controllers : [Principal];
    memory_allocation : Nat;
    compute_allocation : Nat;
  };
  public type user_id = Principal;
  public type wasm_module = [Nat8];

  let IC = actor "aaaaa-aa" : actor {
    canister_status : shared { canister_id : canister_id } -> async {
      status : { #stopped; #stopping; #running };
      memory_size : Nat;
      cycles : Nat;
      settings : definite_canister_settings;
      module_hash : ?[Nat8];
    };
    create_canister : shared { settings : ?canister_settings } -> async {
      canister_id : canister_id;
    };
    delete_canister : shared { canister_id : canister_id } -> async ();
    deposit_cycles : shared { canister_id : canister_id } -> async ();
    install_code : shared {
        arg : [Nat8];
        wasm_module : wasm_module;
        mode : { #reinstall; #upgrade; #install };
        canister_id : canister_id;
      } -> async ();
    provisional_create_canister_with_cycles : shared {
        settings : ?canister_settings;
        amount : ?Nat;
      } -> async { canister_id : canister_id };
    provisional_top_up_canister : shared {
        canister_id : canister_id;
        amount : Nat;
      } -> async ();
    raw_rand : shared () -> async [Nat8];
    start_canister : shared { canister_id : canister_id } -> async ();
    stop_canister : shared { canister_id : canister_id } -> async ();
    uninstall_code : shared { canister_id : canister_id } -> async ();
    update_settings : shared {
        canister_id : Principal;
        settings : canister_settings;
      } -> async ();
    };

  type Bucket = Buckets.Bucket;
  type Service = Types.Service;
  type FileId = Types.FileId;
  type FileInfo = Types.FileInfo;
  type FileData = Types.FileData;
  type Uploader = Types.Uploader;

// canister info hold an actor reference and the result from rts_memory_size
  type CanisterState<Bucket, Nat> = {
    bucket  : Bucket;
    var size : Nat;
  };

  type FileInfoState<Text, FileInfo> = {
    name: Text;
    file: FileInfo;
  };

  type DataChunk<Text, Blob> = {
    id: Text;
    data: Blob;
  };

  type FileDataState<Text, DataChunk> = {
    name: Text;
    chunk: DataChunk;
  } ;
  // canister map is a cached way to fetch canisters info
  // this will be only updated when a file is added 

  stable var _canisterMapState : [(Principal, Nat)] = [];
  private let canisterMap : HashMap.HashMap<Principal, Nat> = HashMap.fromIter(_canisterMapState.vals(), 100, Principal.equal, Principal.hash);


  stable var canisters : [var ?CanisterState<Bucket, Nat>] = Array.init(10, null);

  //Sun: new one
  stable var _bucketState: [Bucket]  = [];
  var _buckets = Buffer.Buffer<Bucket>(10);



  // this is the number I've found to work well in my tests
  // until canister updates slow down 
  //From Claudio:  Motoko has a new compacting gc that you can select to access more than 2 GB, but it might not let you
  // do that yet in practice because the cost of collecting all that memory is too high for a single message.
  // GC needs to be made incremental too. We are working on that.
  // https://forum.dfinity.org/t/calling-arguments-from-motoko/5164/13
  private let threshold = 2147483648; //  ~2GB
  // private let threshold = 50715200; // Testing numbers ~ 50mb

  // each created canister will receive 1T cycles
  // value is set only for demo purposes please update accordingly 
  private let cycleShare = 1_000_000_000_000;


  stable var _admin = owner;
  stable var _moderators = [owner];
  stable var _uploaders : [Uploader] = []; 


  //State functions
  system func preupgrade() {
    _canisterMapState := Iter.toArray(canisterMap.entries());
    _bucketState := _buckets.toArray();
   
  };
  system func postupgrade() {
    _canisterMapState := [];

    // for(x in canisters.vals()){
    //   switch(x){
    //     case(?x){
    //       _buckets.add(x.bucket);
    //     };
    //     case(_){

    //     }
    //   }
      
    // };


    for(b in _bucketState.vals()){
      _buckets.add(b);
    };
    _bucketState:=[];
  };
  // dynamically install a new Bucket
  func newEmptyBucket(): async Bucket {
    Cycles.add(cycleShare);
    let b = await Buckets.Bucket();
    let _ = await updateCanister(b); // update canister permissions and settings
    let s = await b.getSize();
    Debug.print("new canister principal is " # debug_show(Principal.toText(Principal.fromActor(b))) );
    Debug.print("initial size is " # debug_show(s));
    let _ = canisterMap.put(Principal.fromActor(b), threshold);
    //  var v : CanisterState<Bucket, Nat> = {
    //      bucket = b;
    //      var size = s;
    // };
    
    // canisters[canisters.size() + 1] := ?v;
    _buckets.add(b);
    //_buckets := Array.append<CanisterState<Bucket, Nat>>([v],_buckets);
    // canisters := Array.append<?CanisterState<Bucket, Nat>>([?v],canisters);
    b;
  };

  // check if there's an empty bucket we can use
  // create a new one in case none's available or have enough space 
  func getEmptyBucket(s : ?Nat): async Bucket {
    let fs: Nat = switch (s) {
      case null { 0 };
      case (?s) { s }
    };
    let cs: ?(?CanisterState<Bucket, Nat>) =  Array.find<?CanisterState<Bucket, Nat>>(Array.freeze(canisters), 
        func(cs: ?CanisterState<Bucket, Nat>) : Bool {
          switch (cs) {
            case null { false };
            case (?cs) {
              Debug.print("found canister with principal..." # debug_show(Principal.toText(Principal.fromActor(cs.bucket))));
              // calculate if there is enough space in canister for the new file.
              cs.size + fs < threshold 
            };
          };
      });

    let eb : ?Bucket = do ? {
        let c = cs!;
        let nb: ?Bucket = switch (c) {
          case (?c) { 

            //Sun: reserve the new size request
            let _ = _updateBucketStatus(Principal.fromActor(c.bucket),fs);

            ?(c.bucket) 
            };
          case _ { null };
        };

        nb!;
    };
    let c: Bucket = switch (eb) {
        case null { await newEmptyBucket() };
        case (?eb) { eb };
    };
    c
  };


  func getAvailableBucket(s : ?Nat): async Bucket {
    let fs: Nat = switch (s) {
      case null { 0 };
      case (?s) { s }
    };

    let bs = _buckets.toArray();
    let ab = Array.find<Bucket>(bs, func(b: Bucket): Bool{

      let space = canisterMap.get(Principal.fromActor(b));
      switch(space){
        case(?space){
          if(space > fs){
            let _ = updateSize(Principal.fromActor(b),fs);//reserve space
            return true;
          }else{ return false; }
        };
        case(_){
          false
        };
      }

      
    });

    switch(ab){
      case(?ab){
        ab
      };
      case(_){
        await newEmptyBucket()
      };
    }
  };


  private func _updateBucketStatus(id: Principal, incSize: Nat ): () {
    for (i in Iter.range(0, canisters.size() - 1)) {
      let c : ?CanisterState<Bucket, Nat> = canisters[i];
      switch c { 
        case null { };
        case (?c) {
          if(id == Principal.fromActor(c.bucket)){
            c.size := c.size + incSize;
          }
          
        };
      }
    };
  };

  // canister memory is set to 4GB and compute allocation to 5 as the purpose 
  // of this canisters is mostly storage
  // set canister owners to the wallet canister and the container canister ie: this
  func updateCanister(a: actor {}) : async () {
    Debug.print("balance before: " # Nat.toText(Cycles.balance()));
    // Cycles.add(Cycles.balance()/2);
    let cid = { canister_id = Principal.fromActor(a)};
    Debug.print("IC status..."  # debug_show(await IC.canister_status(cid)));
    // let cid = await IC.create_canister(  {
    //    settings = ?{controllers = [?(owner)]; compute_allocation = null; memory_allocation = ?(4294967296); freezing_threshold = null; } } );
    
    await (IC.update_settings( {
       canister_id = cid.canister_id; 
       settings = { 
         controllers = ?[owner, Principal.fromActor(this)];
         compute_allocation = null;
        //  memory_allocation = ?4_294_967_296; // 4GB
         memory_allocation = null; // 4GB
         freezing_threshold = ?31_540_000} })
    );
  };
  // go through each canister and check size
  public func updateStatus(): async () {
    for (i in Iter.range(0, canisters.size() - 1)) {
      let c : ?CanisterState<Bucket, Nat> = canisters[i];
      switch c { 
        case null { };
        case (?c) {
          let s = await c.bucket.getSize();
          let cid = { canister_id = Principal.fromActor(c.bucket)};
          // Debug.print("IC status..." # debug_show(await IC.canister_status(cid)));
          Debug.print("canister with id: " # debug_show(Principal.toText(Principal.fromActor(c.bucket))) # " size is " # debug_show(s));
          c.size := s;
          let _ = updateSize(Principal.fromActor(c.bucket), s);
        };
      }
    };
  };

  // update hashmap 
  func updateSize(p: Principal, s: Nat) : () {
    var r = 0;
    if (s < threshold) {
      r := threshold - s;
    };
    let _ = canisterMap.replace(p, r);
  };


  public  shared({caller}) func setAdmin(admin: Principal): async Result.Result<Nat,Text>{
    if(admin == caller){
      _admin := admin;
      #ok(1)
    }else{
      #err("no permission")
    };
    
  };

  public query func getAdmin(): async Principal{
    _admin;
  };


  public  shared({caller}) func addModerator(md: Principal): async Result.Result<Nat, Text>{
    if(caller == _admin){
       _moderators := Array.append<Principal>([md],_moderators);
       #ok(1)
    }else{
      #err("no permission")
    }
  };

  public query func getModerators(): async [Principal]{
    _moderators;
  };

  public  shared({caller}) func setUploaders(uploader: Principal, quota: Nat): async Result.Result<Nat, Text>{
    let fmod = Array.find(_moderators,func(m: Principal): Bool{
      m == caller
    });
    switch(fmod){
      case(?fmod){
        let fu = Array.find<Uploader>(_uploaders, func(u:Uploader ): Bool{
           u.uploader == uploader
         });
          switch(fu){
            case(?fu){
              _uploaders := Array.map<Uploader,Uploader>(_uploaders,func(u): Uploader{
                if(u.uploader == uploader){
                  {
                    uploader = uploader;
                    quota = u.quota + quota;
                    files = u.files;
                  }
                }else{
                  u
                }
              })
            };
            case(_){
              _uploaders := Array.append([{
                  uploader = uploader;
                  quota =  quota;
                  files = [];
              }],_uploaders);
            }
          };
        #ok(1);
      };
      case(_){
        #err("no permission!")
      }

    }
   

  };

  public query({caller}) func getUploaders(): async [Uploader]{
    assert(caller == _admin);
    _uploaders;
  };

  public query({caller}) func getFileIds(): async [FileId]{
    let uploader = Array.find<Uploader>(_uploaders, func(u: Uploader):Bool{
      u.uploader == caller
    });

    switch(uploader){
      case(?uploader){
        uploader.files;
      };
      case(_){
        []
      };
    };
  };

  public query({caller}) func getQuota(): async {used: Nat; quota: Nat;}{
    let up = Array.find<Uploader>(_uploaders, func(u: Uploader):Bool{
      u.uploader == caller
    });
    switch(up){
      case(?up){
        {
          used = up.files.size();
          quota = up.quota;
        }
      };
      case(_){
        {
          used = 0;
          quota = 0;
        }
      };
    }
  };

  // persist chunks in bucket
  public shared({caller}) func putFileChunks(fileId: FileId, chunkNum : Nat, fileSize: Nat, chunkData : Blob) : async Result.Result<Nat, Text> {


          let b : Bucket = await getEmptyBucket(?fileSize);
          let _ = await b.putChunks(fileId, chunkNum, chunkData);
          #ok(1)
       

  };
  // persist chunks in bucket
  public shared({caller}) func saveFileChunks(fileId: FileId, chunkNum : Nat, fileSize: Nat, chunkData : Blob) : async Result.Result<Nat, Text> {


          // let b : Bucket = await getEmptyBucket(?fileSize);
           let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];



                let r =  do ? {
                    let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
          
                    let _ = await b.putChunks(fileId, chunkNum, chunkData);
                    
                    ?1;
                  };  
                  
                  #ok(1)
            

  };

  // save file info 
  public shared({caller}) func putFileInfo(fi: FileInfo) : async Result.Result<FileId, Text> {

   let fu = Array.find<Uploader>(_uploaders, func(u:Uploader ): Bool{
      u.uploader == caller
    });

    switch(fu){
      case(?fu){

        if(fu.quota > fu.files.size()){
          
          // let b: Bucket = await getEmptyBucket(?fi.size);
          let b: Bucket = await getAvailableBucket(?fi.size);
          Debug.print("creating file info..." # debug_show(fi));
          let fileId = await b.putFile(fi);
          
          

          switch(fileId){
            case(?fileId){

               
                //update uploaders
                
                _uploaders := Array.map<Uploader,Uploader>(_uploaders,func(u): Uploader{
                  if(u.uploader == caller){
                    {
                      uploader = u.uploader;
                      quota = u.quota;
                      files = Array.append<FileId>([fileId],u.files);
                    }
                  }else{
                    u
                  }
              });
              #ok(fileId)
            };
            case(_){
              #err("no file id generated!")
            }
          }
          
        }else{
          #err("no more quota!")
        };

      };
      case(_){
        #err("no permission")
      }
    };    

  };

  

  func getBucket(cid: Principal) : async ?Bucket {
    let cs: ?(?CanisterState<Bucket, Nat>) =  Array.find<?CanisterState<Bucket, Nat>>(Array.freeze(canisters), 
        func(cs: ?CanisterState<Bucket, Nat>) : Bool {
          switch (cs) {
            case null { false };
            case (?cs) {
              Debug.print("found canister with principal..." # debug_show(Principal.toText(Principal.fromActor(cs.bucket))));
              Principal.equal(Principal.fromActor(cs.bucket), cid)
            };
          };
      });
      let eb : ?Bucket = do ? {
        let c = cs!;
        let nb: ?Bucket = switch (c) {
          case (?c) { ?(c.bucket) };
          case _ { null };
        };

        nb!;
    };
  };

  func _getBucket(cid: Principal): async ?Bucket{
    let abuckets = _buckets.toArray();
    Array.find<Bucket>(abuckets,func(b: Bucket): Bool{
      cid == Principal.fromActor(b)
    });
  };

  // // get file chunk 
  // public func getFileChunk(fileId : FileId, chunkNum : Nat) : async ?Blob {
  //   let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];
  //   do ? {
  //     let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
  //     return await b.getChunks(fileId, chunkNum);
  //   }   
  // };

  // // get file info
  // public func getFileInfo(fileId : FileId) : async ?FileData {
  //   let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];
  //   do ? {
  //     let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
  //     return await b.getFileInfo(fileId);
  //   }   
  // };



  // get file chunk 
  public func fetchFileChunk(fileId : FileId, chunkNum : Nat) : async ?Blob {
    let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];

        do ? {
          let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
          return await b.getChunks(fileId, chunkNum);
        }  ; 

    
  };

  public func fetchFileChunks(fileId: FileId) : async ?Blob{
     let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];
     

        do ? {
          let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
          let f = await b.getFileInfo(fileId);
          switch(f){
            case(?f){
              var cs = Buffer.Buffer<Blob>(f.chunkCount);
              for (j in Iter.range(0, f.chunkCount)) {
                let chunk = await b.getChunks(fileId, j);
                switch(chunk){
                  case(?chunk){
                    cs.add(chunk);
                  };
                  case(_){
                    
                  };
                };
                
              };
              mergeChunks(cs.toArray());
            };
            case(_){
              Blob.fromArray([])
            };
          }
         
        }; 

  };
  
  private func mergeChunks (chunks : [Blob]) : Blob {
      Blob.fromArray(
          Array.foldLeft<Blob, [Nat8]>(chunks, [], func (a : [Nat8], b : Blob) {
              Array.append(a, Blob.toArray(b));
          })
      );
  };

  // get file info
  public  func fetchFileInfo(fileId : FileId) : async ?FileData {
        let cid = Iter.toArray(Text.tokens(fileId, #text("_")))[0];

        do ? {
          let b : Bucket = (await _getBucket(Principal.fromText(cid)))!;
          return await b.getFileInfo(fileId);
        }   
     
    
  };



  // get canisters status
  // this is cached until a new upload is made
  public query func getStatus() : async [(Principal, Nat)] {
    Iter.toArray<(Principal, Nat)>(canisterMap.entries());
  };

  // public query func getCycles() : async [(Principal, Nat)] {
  //   let bs = _buckets.toArray();
  //   var cs = Buffer.Buffer<(Principal, Nat)>(1+bs.size());
    
  //   cs.add((Principal.fromActor(this),Cycles.balance()));

  //   for(b in bs.vals()){
  //     let balance =  b.wallet_balance();
  //     cs.add(Principal.fromActor(b),balance);
  //   };

  //   cs.toArray();
    
  // };

  // public query func getBuckets(): async [Bucket]{
  //   _buckets.toArray();
  // };

  // get a list of files from all canisters
  // public func getAllFiles() : async [FileData] {
  //   let buff = Buffer.Buffer<FileData>(0);
  //   for (i in Iter.range(0, canisters.size() - 1)) {
  //     let c : ?CanisterState<Bucket, Nat> = canisters[i];
  //     switch c { 
  //       case null { };
  //       case (?c) {
  //         let bi = await c.bucket.getInfo();
  //         for (j in Iter.range(0, bi.size() - 1)) {
  //           buff.add(bi[j])
  //         };
  //       };
  //     }
  //   };
  //   buff.toArray()
  // };  

  public shared({caller = caller}) func wallet_receive() : async () {
    ignore Cycles.accept(Cycles.available());
  };

  
  public query func availableCycles() : async Nat {
    return Cycles.balance();
  };

public query func getSystemData(): async {
       cycles: Nat;
      memory: Nat;
      heap: Nat;
   }{
    return {
      cycles = Cycles.balance();
      memory = Prim.rts_memory_size();
      heap = Prim.rts_heap_size();
    };
  } ;

};

  