// 3rd Party Imports

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
// import Ext "mo:ext/Ext";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Text "mo:base/Text";


import Types "types";



module {

    public class HttpHandler () {

        private func getContentType(ext: Types.FileExtension): Text{
        
            switch(ext) {
                case(#jpeg){
                    "image/jpeg"
                };
                case(#gif){
                    "image/gif"
                };
                case(#jpg){
                    "image/jpg"
                };                                
                case(#png){
                    "image/png"
                };                
                case(#svg){
                    "image/svg"
                };
                case(#avi){
                    "video/avi"
                };
                case(#mp4){
                    "video/mp4"
                };
                case(#aac){
                    "video/aac"
                };
                case(#wav){
                    "audio/wav"
                };
                case(#mp3){
                    "audio/mp3"
                }; 
                case(_){
                    "text/plain"
                }                                                                                               
            };
        };





        // @path: *?tokenid

        public func httpIndex(request : Types.Request) : Types.Response {
            //let tokenId = Iter.toArray(Text.tokens(request.url, #text("tokenid=")))[1];
            // let { index } = Stoic.decodeToken(tokenId);

                // let path = Iter.toArray(Text.tokens(request.url, #text("/")));
               
                return {
                    status_code = 200;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8 (
                        "Asset Management" 
                    );
                    streaming_strategy = null;
                };

        };


     
      
        public func renderMesssage(message: Text): Types.Response{
                return {
                    status_code = 200;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8 (
                        message
                    );
                    streaming_strategy = null;
                };
        };
   


        // A 404 response with an optional error message.
        private func http404(msg : ?Text) : Types.Response {
            {
                body = Text.encodeUtf8(
                    switch (msg) {
                        case (?msg) msg;
                        case null "Not found.";
                    }
                );
                headers = [
                    ("Content-Type", "text/plain"),
                ];
                status_code = 404;
                streaming_strategy = null;
            };
        };


        // A 400 response with an optional error message.
        private func http400(msg : ?Text) : Types.Response {
            {
                body = Text.encodeUtf8(
                    switch (msg) {
                        case (?msg) msg;
                        case null "Bad request.";
                    }
                );
                headers = [
                    ("Content-Type", "text/plain"),
                ];
                status_code = 400;
                streaming_strategy = null;
            };
        };



        public func request(request : Types.Request) : Types.Response {
            

            // if (Text.contains(request.url, #text("id"))) {
            //     let fid = Iter.toArray(Text.tokens(request.url, #text("id=")))[1];
               
            //     return renderMesssage();
            // }else{
                return httpIndex(request);
            // }

            
        };
    };
};