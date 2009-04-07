{-----------------------------------------------------------------------------
 -
 -                FPR - Functional and Logic Programming
 -             Project 1: Lightweight XMPP server in Haskell
 -
 -                            Ondrej Lengal
 -                      xlenga00@stud.fit.vutbr.cz
 -
 -                   Faculty of Information Technology
 -                     Brno University of Technology
 -
 - This module contains global definitions to be used in all other modules.
 -
 -----------------------------------------------------------------------------}

{-|
  This module contains global definitions to be used in all other modules.
 -}
module Global where

import Data.List
  (foldl')
import System.IO
  (Handle, hPutStrLn, stderr)
import Control.Concurrent.STM
  (TChan)
import Control.Monad
  (when)


{-|
  The constant that determines whether we are debugging.
 -}
debug :: Bool        -- ^ The value of the debug constant
debug = True
--debug = False


{-|
  The DTD for output XML.
 -}
xmlDtd :: String      -- ^ The DTD for output XML
xmlDtd = "<?xml version=\"1.0\"?>"


{-|
  The string constant with the namespace for XMPP streams.
 -}
streamNamespace :: String             -- ^ The XMPP stream namespace
streamNamespace = "http://etherx.jabber.org/streams"


{-|
  The string constant with the client namespace.
 -}
clientNamespace :: String             -- ^ The client namespace
clientNamespace = "jabber:client"


{-|
  The string constant with the defaul language of the XML.
 -}
defaultXMLLang :: String              -- ^ Default XML language
defaultXMLLang = "en"


{-|
  The string constant with the server namespace.
 -}
serverNamespace :: String             -- ^ The server namespace
serverNamespace = "jabber:server"


{-|
  The string constant with the namespace used for authentication
 -}
authNamespace :: String               -- ^ The authentication namespace
authNamespace = "jabber:iq:auth"


{-|
  The string constant with the SASL namespace
 -}
saslNamespace :: String               -- ^ The SASL namespace
saslNamespace = "urn:ietf:params:xml:ns:xmpp-sasl"


{-|
  The string constant with the IQ authentication namespace
 -}
iqAuthNamespace :: String             -- ^ The IQ auth namespace
iqAuthNamespace = "http://jabber.org/features/iq-auth"


{-|
  The data type for command as is generated by the XMPP parser and send to the
  command engine.
 -}
data Command
  = Error String                    -- ^ An error with description
  | EndOfStream                     -- ^ End of client stream
  | OpenStream String String        -- ^ Stream opening command. The parameters
                                    --   are:
                                    --     * the XML language
                                    --     * the XMPP version
  | Authenticate AuthStruct String  -- ^ Client authentication command with
                                    --   the authentication structure and the
                                    --   ID of the authentication request
  deriving (Show)


{-|
  The Jabber ID:

     * The node

     * The domain

     * The resource
 -}
type JID = (String, String, String)


{-|
  The authentication structure

     * The name

     * The password

     * The resource

  If a field is missing, there is Nothing instead.
 -}
type AuthStruct = (Maybe String, Maybe String, Maybe String)


{-|
  This function initializes an 'AuthStruct'.
 -}
initAuthStruct :: AuthStruct           -- ^ The initialized 'AuthStruct'
initAuthStruct = (Nothing, Nothing, Nothing)


{-|
  The 'setUsername' function sets a username of an 'AuthStruct' structure.
 -}
setUsername :: AuthStruct   -- ^ The 'AuthStruct' structure
            -> String       -- ^ The username
            -> AuthStruct   -- ^ The resulting 'AuthStruct'
setUsername (_, passwd, resource) username = (Just username, passwd, resource)


{-|
  The 'setPassword' function sets a password of an 'AuthStruct' structure.
 -}
setPassword :: AuthStruct   -- ^ The 'AuthStruct' structure
            -> String       -- ^ The password
            -> AuthStruct   -- ^ The resulting 'AuthStruct'
setPassword (username, _, resource) passwd = (username, Just passwd, resource)


{-|
  The 'setResource' function sets a resource of an 'AuthStruct' structure.
 -}
setResource :: AuthStruct   -- ^ The 'AuthStruct' structure
            -> String       -- ^ The resource
            -> AuthStruct   -- ^ The resulting 'AuthStruct'
setResource (username, passwd, _) resource = (username, passwd, Just resource)


{-|
  The data type for the state of the client.

  The state transition diagram:
 
  @
    START  +--------+       AUTHENTICATE        +------+
   ------> | UNAUTH | ------------------------> | AUTH |
           +--------+                           +------+
               |                                   |
               |                                   |
               |                                   |
               |   REJECT                 ERROR    |
               +-------------+        +------------+
                             |        |   CLOSE
                             |        |
                             |        |
                             |        |
                             V        V
                          CLOSE CONNECTION
  @
 -}
data State
  = Unauth      -- ^ The Unauthenticated state
  | Auth        -- ^ The Authenticated state


{-|
  The data type representing a XML node. The first field is the name of the
  node, the second is the list of attributes and the third one is the list of
  content of the node (either other nodes or strings).
 -}
type XmlNode = (String, [XmlAttribute], [XmlContent])


{-|
  The data type for XML attribute. It is a tuple of strings with the first
  string being the name of the attribute and the second string being the value
  of the attribute.
 -}
type XmlAttribute = (String, String)


{-|
  The data type for the content of a XML node. It can be either a string or
  another XML node.
 -}
data XmlContent
  = XmlContentNode XmlNode    -- ^ An XML node
  | XmlContentString String   -- ^ A string

{-|
  The 'serializeXmlNode' function serializes a tree represented by an XML node
  into a string.
 -}
serializeXmlNode :: XmlNode     -- ^ The root of the tree to be serialized
                 -> String      -- ^ Serialized tree
serializeXmlNode (name, attrs, content) = case content of
  []   -> "<" ++ openingTagContent ++ "/>"
  cont -> serializeXmlNodeOpeningTag (name, attrs, content)
            ++ (concat . map (serializeXmlContent)) cont
            ++ serializeXmlNodeClosingTag (name, attrs, content)
  where openingTagContent = name ++ serializeXmlAttributes attrs


{-|
  This function converts the XML node into a string with the opening tag. This
  is necessary for opening the <stream> document and possibly for other tags.
 -}
serializeXmlNodeOpeningTag :: XmlNode   -- ^ The XML node
                           -> String    -- ^ String with the opening tag
serializeXmlNodeOpeningTag (name, attrs, _) =
  "<" ++ name ++ serializeXmlAttributes attrs ++ ">"


{-|
  This function converts the XML node into a string with the closing tag. This
  is necessary for closing the <stream> document and possibly for other tags.
 -}
serializeXmlNodeClosingTag :: XmlNode   -- ^ The XML node
                           -> String    -- ^ String with the closing tag
serializeXmlNodeClosingTag (name, _, _) = "</" ++ name ++ ">"


{-|
  This function serializes list of XML attributes into a string.
 -}
serializeXmlAttributes :: [XmlAttribute]  -- ^ List of XML attributes
                       -> String          -- ^ The output string
serializeXmlAttributes attrs =
  foldl' (\z x -> " " ++ attrStr z x) "" attrs
  where attrStr z x = attributeToXmlString x ++ z
        attributeToXmlString (name, value) =
          name ++ "=\"" ++ stringToXmlString value ++ "\""


{-|
  The 'serializeXmlContent' function serializes non-empty XML node content
  into a string.
 -}
serializeXmlContent :: XmlContent   -- ^ The XML content to be serialized
                    -> String       -- ^ The output string
serializeXmlContent (XmlContentNode node) = serializeXmlNode node
serializeXmlContent (XmlContentString str) = stringToXmlString str

{-|
  This function converts a string into a valid XML string with proper escape
  sequences.
 -}
stringToXmlString :: String     -- ^ The input string
                  -> String     -- ^ The output string
stringToXmlString str = foldl' (\x y -> x ++ charToXmlString y) "" str
  where charToXmlString char = case char of
          '<'  -> "&lt;"
          '>'  -> "&gt;"
          '&'  -> "&amp;"
          '\'' -> "&apos;"
          '"'  -> "&quot;"
          y    -> y:[]


{-|
  The data type with 'Client' information, i.e. the command channel that is
  used for communication with the main thread, the handle of the socket the
  client is connected to, the state of the client, and the client JID.
 -}
type Client = (TChan Command, Handle, State, JID)


{-|
  This is the constructor for the client data type. It takes the command
  channel and the client handler thread and returns a default client
  structure.
 -}
initClient :: TChan Command    -- ^ The channel the client sends commands to
           -> Handle           -- ^ The handle of the client processing thread
           -> Client           -- ^ An initialized client
initClient command handle = (command, handle, Unauth, ("", "", ""))


{-|
  The accessor for handle field of a Client.
 -}
clientGetHandle :: Client    -- ^ The client
                -> Handle    -- ^ The handle of the client
clientGetHandle (_, handle, _, _) = handle


{-|
  Prints a debugging information string (in case debugging is turned on).
 -}
debugInfo :: String      -- ^ The string to be printed
          -> IO ()       -- ^ The return value
debugInfo str = when (debug) $ hPutStrLn stderr str
--debugInfo [] = hPutStr stderr "\n"
--debugInfo (x:xs) = when (debug) $ do
--  hPutStr stderr [x]
--  hFlush stderr
--  debugInfo xs
