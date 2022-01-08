export const idlFactory = ({ IDL }) => {
  const Timestamp = IDL.Int;
  const FileId__1 = IDL.Text;
  const FileExtension = IDL.Variant({
    'aac' : IDL.Null,
    'avi' : IDL.Null,
    'gif' : IDL.Null,
    'jpg' : IDL.Null,
    'mp3' : IDL.Null,
    'mp4' : IDL.Null,
    'png' : IDL.Null,
    'svg' : IDL.Null,
    'wav' : IDL.Null,
    'jpeg' : IDL.Null,
  });
  const FileData = IDL.Record({
    'cid' : IDL.Principal,
    'name' : IDL.Text,
    'createdAt' : Timestamp,
    'size' : IDL.Nat,
    'fileId' : FileId__1,
    'chunkCount' : IDL.Nat,
    'extension' : FileExtension,
    'uploadedAt' : Timestamp,
  });
  const FileId = IDL.Text;
  const FileInfo = IDL.Record({
    'name' : IDL.Text,
    'createdAt' : Timestamp,
    'size' : IDL.Nat,
    'chunkCount' : IDL.Nat,
    'extension' : FileExtension,
  });
  const Container = IDL.Service({
    'getAllFiles' : IDL.Func([], [IDL.Vec(FileData)], []),
    'getFileChunk' : IDL.Func(
        [FileId, IDL.Nat, IDL.Principal],
        [IDL.Opt(IDL.Vec(IDL.Nat8))],
        [],
      ),
    'getFileInfo' : IDL.Func([FileId, IDL.Principal], [IDL.Opt(FileData)], []),
    'getStatus' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Principal, IDL.Nat))],
        ['query'],
      ),
    'putFileChunks' : IDL.Func(
        [FileId, IDL.Nat, IDL.Nat, IDL.Vec(IDL.Nat8)],
        [],
        [],
      ),
    'putFileInfo' : IDL.Func([FileInfo], [IDL.Opt(FileId)], []),
    'updateStatus' : IDL.Func([], [], []),
    'wallet_receive' : IDL.Func([], [], []),
  });
  return Container;
};
export const init = ({ IDL }) => { return []; };
