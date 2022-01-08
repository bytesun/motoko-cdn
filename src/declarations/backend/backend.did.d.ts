import type { Principal } from '@dfinity/principal';
export interface Container {
  'getAllFiles' : () => Promise<Array<FileData>>,
  'getFileChunk' : (arg_0: FileId, arg_1: bigint, arg_2: Principal) => Promise<
      [] | [Array<number>]
    >,
  'getFileInfo' : (arg_0: FileId, arg_1: Principal) => Promise<[] | [FileData]>,
  'getStatus' : () => Promise<Array<[Principal, bigint]>>,
  'putFileChunks' : (
      arg_0: FileId,
      arg_1: bigint,
      arg_2: bigint,
      arg_3: Array<number>,
    ) => Promise<undefined>,
  'putFileInfo' : (arg_0: FileInfo) => Promise<[] | [FileId]>,
  'updateStatus' : () => Promise<undefined>,
  'wallet_receive' : () => Promise<undefined>,
}
export interface FileData {
  'cid' : Principal,
  'name' : string,
  'createdAt' : Timestamp,
  'size' : bigint,
  'fileId' : FileId__1,
  'chunkCount' : bigint,
  'extension' : FileExtension,
  'uploadedAt' : Timestamp,
}
export type FileExtension = { 'aac' : null } |
  { 'avi' : null } |
  { 'gif' : null } |
  { 'jpg' : null } |
  { 'mp3' : null } |
  { 'mp4' : null } |
  { 'png' : null } |
  { 'svg' : null } |
  { 'wav' : null } |
  { 'jpeg' : null };
export type FileId = string;
export type FileId__1 = string;
export interface FileInfo {
  'name' : string,
  'createdAt' : Timestamp,
  'size' : bigint,
  'chunkCount' : bigint,
  'extension' : FileExtension,
}
export type Timestamp = bigint;
export interface _SERVICE extends Container {}
