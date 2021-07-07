import Types "./Types";
import Random "mo:base/Random";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import Prim "mo:prim";
import Buffer "mo:base/Buffer";

actor class Bucket () {

  type FileId = Types.FileId;
  type FileInfo = Types.FileInfo;
  type FileData = Types.FileData;
  type ChunkId = Types.ChunkId;
  type State = Types.State;

  var state = Types.empty();

  public func getSize(): async Nat {
    Prim.rts_memory_size();
  };

  func chooseMax(f : Random.Finite) : ? Nat8 {
    do ? {
      f.byte()!
    };
  };

  public func generateRandom(name: Text): async Text {
    var n : Text = name;
    let entropy = await Random.blob(); // get initial entropy
    var f = Random.Finite(entropy);
    // append 2 bytes of entropy to the name
    let count : Nat = 2;
    var i = 1;
    label l loop {
      if (i >= count) break l;
      let b = chooseMax(f);
      switch (b) {
        case (?b) { n := n # Nat8.toText(b); i += 1 };
        case null { // not enough entropy
          Debug.print("need more entropy...");
          let entropy = await Random.blob(); // get more entropy
          f := Random.Finite(entropy);
        };
      };
      
    };
    
    n
  };

  func createFileInfo(fileId: Text, fi: FileInfo) : ?FileId {
          switch (state.files.get(fileId)) {
              case (?_) { /* error -- ID already taken. */ null }; 
              case null { /* ok, not taken yet. */
                  Debug.print("id is..." # debug_show(fileId));   
                  state.files.put(fileId,
                                      {
                                          fileId = fileId;
                                          name = fi.name;
                                          createdAt = fi.createdAt;
                                          uploadedAt = Time.now();
                                          chunkCount = fi.chunkCount;
                                          size = fi.size ;
                                          extension = fi.extension;
                                      }
                  );
                  ?fileId
              };
          }
  };

  public func putFile(fi: FileInfo) : async ?FileId {
    do ? {
      // append 2 bytes of entropy to the name
      let fileId = await generateRandom(fi.name);
      createFileInfo(fileId, fi)!;
    }
  };

  func chunkId(fileId : FileId, chunkNum : Nat) : ChunkId {
      fileId # (Nat.toText(chunkNum))
  };

  public func putChunks(fileId : FileId, chunkNum : Nat, chunkData : Blob) : async ?() {
    do ? {
      Debug.print("generated chunk id is " # debug_show(chunkId(fileId, chunkNum)) # "from"  #   debug_show(fileId) # "and " # debug_show(chunkNum)  #"  and chunk size..." # debug_show(Blob.toArray(chunkData).size()) );
      state.chunks.put(chunkId(fileId, chunkNum), chunkData);
    }
  };

  func getFileInfoData(fileId : FileId) : ?FileData {
      do ? {
          let v = state.files.get(fileId)!;
            {
            fileId = v.fileId;
            name = v.name;
            size = v.size;
            chunkCount = v.chunkCount;
            extension = v.extension;
            createdAt = v.createdAt;
            uploadedAt = v.uploadedAt;
          }
      }
  };

  public query func getFileInfo(fileId : FileId) : async ?FileData {
    do ? {
      getFileInfoData(fileId)!
    }
  };

  public query func getChunks(fileId : FileId, chunkNum: Nat) : async ?Blob {
    do ? {
      state.chunks.get(chunkId(fileId, chunkNum))!
    }
  };

  public query func getBucketInfo() : async [FileData] {
    let b = Buffer.Buffer<FileData>(0);
    let _ = do ? {
      for ((f, _) in state.files.entries()) {
        b.add(getFileInfoData(f)!)
      };
    };
    b.toArray()
  };

};
