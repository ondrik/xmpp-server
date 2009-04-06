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
 - This module contains global functions for XMPP parser.
 -
 -----------------------------------------------------------------------------}

{-|
  This module contains global functions for XMPP parser.
  -}
module ParserGlobal
  (showSax, sendCommand, getAttributeValue, getValueOfAttribute, safely,
  safelyWorkWithAttribute, matchesStringForPrefix) where

import Control.Concurrent.STM
  (TChan, writeTChan, atomically)

import Text.XML.HaXml.SAX
  (SaxElement(..), saxParse)
import Text.XML.HaXml
  (Attribute, AttValue(..), Reference)

import Global


{-|
  The 'showSax' function is a debug function for transformation of an
  arbitrary SAX element into a string.
 -}
showSax :: SaxElement     -- ^ The SAX element
        -> String         -- ^ The string representation of the SAX element
showSax element =
  case element of
    (SaxComment comment) ->
      "Comment: " ++ comment ++ " INVALID XMPP-XML ELEMENT!" ++ "\n"
    (SaxElementOpen open_tag_name attrs) ->
      "Element open: " ++ (cropQuotes $ show open_tag_name)
      ++ "\n  Attributes: " ++ (showAttributes attrs) ++ "\n"
    (SaxElementClose close_tag_name) ->
      "Element close: " ++ (cropQuotes $ show close_tag_name) ++ "\n"
    (SaxElementTag tag_name attrs) ->
      "Element empty: " ++ (cropQuotes $ show tag_name) ++ "\n  Attributes: "
      ++ (showAttributes attrs) ++ "\n"
    (SaxCharData char_data) ->
      "Character data: " ++ (cropQuotes $ show char_data) ++ "\n"
    (SaxDocTypeDecl _) ->
      "DocType: " ++ " INVALID XMPP-XML ELEMENT!" ++ "\n"
    (SaxProcessingInstruction (target, str)) ->
      "Processing instruction: " ++ target ++ " --- " ++ str
      ++ " INVALID XMPP-XML ELEMENT!" ++ "\n"
    (SaxReference _) ->
      "Reference: " ++ " INVALID XMPP-XML ELEMENT!" ++ "\n"


{-|
  The 'showAttributes' function converts a list of XML attributes into
  a string.
 -}
showAttributes :: [Attribute]       -- ^ The string of XML attributes
               -> String            -- ^ The output string
showAttributes attrs = foldr ((++) . (++ " ") . showAttr ) "" attrs
  where showAttr (name, AttValue value) =
          name ++ "=\"" ++ (showAttrValue $ head value) ++ "\""


{-|
  This function shows the attribute value.
 -}
showAttrValue :: Either String Reference   -- ^ The attribute value: either
                                           --   a string or a reference
              -> String                    -- ^ The output attribute value
showAttrValue (Left str) = str
showAttrValue _ = error "XMPP does not support other XML attributes than strings!"


{-|
  This function gets the value of an attribute with given name from a list of
  attributes.
 -}
getValueOfAttribute :: [Attribute]   -- ^ List of attributes
                    -> String        -- ^ Name of the attribute to be retrieved
                    -> Maybe String  -- ^ The attribute value or Nothing
getValueOfAttribute [] _ = Nothing
getValueOfAttribute ((attName, attValue):xs) name =
  if (attName == name)
    then getAttributeValue attValue
    else xs `getValueOfAttribute` name


{-|
  Gets the value of an attribute. It gets the first string in the attribute
  value list, or Nothing, if there is no value.
 -}
getAttributeValue :: AttValue      -- ^ The attribute value list
                  -> Maybe String  -- ^ The value of the attribute (or Nothing)
getAttributeValue (AttValue []) = Nothing
getAttributeValue (AttValue (x:_)) = case x of
  (Left value) -> Just value   -- if there is a string
  _ -> Nothing                 -- if there is something else


safelyWorkWithAttribute attrs chan attrName f = do
  let attr = attrs `getValueOfAttribute` attrName
  case attr of
    -- in case the attribute is not in the list
    Nothing -> sendCommand chan $ Error ("Could not find attribute \""
                 ++ attrName ++ "\" in the list of attributes!")
    -- in case the attribute is in the list
    (Just value) -> f value


{-|
  The 'safely' construction is to be used when processing SAX parser events.
  It either processes the function passed in the handler parameter or in case
  of an error, it sends the error message to the channel.
 -}
safely :: TChan Command                 -- ^ The channel for sending commands
       -> [Maybe SaxElement]            -- ^ The input list of SAX events 
       -> (SaxElement -> [Maybe SaxElement] -> IO ())
          -- ^ The function that handles correct SAX events
       -> IO ()                         -- ^ The return value
safely chan elements handler = do
  case elements of
    [] -> do                    -- end of stream
      debugInfo "End of stream!"
      sendCommand chan EndOfStream
    (Nothing:_) -> do           -- an error
      debugInfo "Error!"
      sendCommand chan $ Error "XML format error!"
    ((Just x):xs) -> do         -- a valid SAX element
      debugInfo $ showSax x
      handler x xs


{-|
  This function crops leading and trailing double quote marks from a string.
 -}
cropQuotes :: String       -- ^ The input string
           -> String       -- ^ The output string (with leading and trailing
                           --   double quote marks removed)
cropQuotes     [] = []
cropQuotes (x:xs) = if (x == '\"') then cropEnd xs else x:(cropEnd xs)
  where cropEnd = foldr (\y z -> if (z == "\"") then [y] else (y:z)) ""


matchesStringForPrefix str target prefix =
  (str == target) || (str == prefix ++ ":" ++ target)


{-|
  The function that sends a command to a command channel.
 -}
sendCommand :: TChan Command    -- ^ The command channel
            -> Command          -- ^ The command to be sent
            -> IO ()            -- ^ The return value
sendCommand chan = atomically . writeTChan chan