import 'dart:convert';
import 'dart:io';

import 'package:g2g/models/clientModel.dart';
import 'package:g2g/utility/hashSha256.dart';

import 'package:g2g/constants.dart';
import 'package:g2g/utility/pref_helper.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml2json/xml2json.dart';

class ClientController {

  Future<String> authenticateUser()async{
     SharedPreferences prefs=await SharedPreferences.getInstance();
     var userID = 'WEBSERVICES';
     var password = 'G2GW3bs3rv1c35';
     Map hashAndSalt =hashSHA256(userID+ password);
     print('$apiBaseURL/Authentication/AuthenticateUser?subscriberId=$subscriberID&userId=$userID&password=$password&hash=${hashAndSalt['hash']}&hashSalt=${hashAndSalt['salt']}');

     http.Response response=await http.get('$apiBaseURL/Authentication/AuthenticateUser?subscriberId=$subscriberID&userId=$userID&password=$password&hash=${hashAndSalt['hash']}&hashSalt=${hashAndSalt['salt']}');
    print(response.body);
    var webUserResponse = jsonDecode(response.body);
    if (webUserResponse['SessionToken'] !=null){
      
      prefs.setString(PrefHelper.PREF_AUTH_TOKEN,webUserResponse['SessionToken'] );
      
      // prefs.setString('user', response.body);
      return webUserResponse['SessionToken'];
    
     
    }
    else if (webUserResponse["Code"] =="Subscriber.InvalidHash"){
       return await authenticateUser();
    }
    return null;
  }
  Future<Client> authenticateClient(String clientID,String password,bool isWebAuthenticated) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String ePass = isWebAuthenticated?password:getEncryptPassword(password);
    String envelope =
        '<ClientAuthentication>\r\n<UserID>$clientID<\/UserID>\r\n<Password>$ePass<\/Password>\r\n<\/ClientAuthentication>';
    http.Response response = await http.post(
      '$apiBaseURL/custom/ClientLogin',
      headers: <String, String>{
        'Content-Type': 'text/plain',
        'Authorization': 'AuthFinWs token="${prefs.getString(PrefHelper.PREF_AUTH_TOKEN)}"'
      },
      body: envelope,
    );
    print(response.body);
    final myTransformer = Xml2Json();
    myTransformer.parse(response.body);
    var json = myTransformer.toParker();
    print(json);
    var innerJson = jsonDecode(json)['ClientAuthentication']['SessionDetails'];
    print(innerJson);
    // print(response.body);
    // var _document = xml.parse(response.body);
    // var innerJson = "";
    // Iterable<xml.XmlElement> items =
    //     _document.findAllElements('ClientAuthentication');
    // items.map((xml.XmlElement item) {
    //   innerJson = _getValue(item.findElements("SessionDetails"));
    // }).toList();
    if(jsonDecode(json)['ClientAuthentication']['SessionError']!=null){
        return await authenticateClient(clientID, ePass,isWebAuthenticated);
    }

   else if (innerJson['SessionToken'] != null) {
      prefs.setBool('isLoggedIn', true);
      prefs.setString(PrefHelper.PREF_USER_ID,clientID);
      prefs.setString(PrefHelper.Pref_CLIENT_ID, innerJson['ClientId']);
      prefs.setString(PrefHelper.PREF_SESSION_TOKEN, innerJson['SessionToken']);
      prefs.setString(PrefHelper.PREF_PASSWORD, ePass);
      // prefs.setString('user', response.body);
      return Client.fromJson(innerJson);
    } else if (jsonDecode(response.body)["Code"] == "Subscriber.InvalidHash") {
      return await authenticateClient(clientID, ePass,isWebAuthenticated);
    } else {
      return null;
    }
  }

  _getValue(Iterable<xml.XmlElement> items) {
    var textValue;
    items.map((xml.XmlElement node) {
      textValue = node.text;
    }).toList();
    return textValue;
  }

  Future<Map> getClientBasic() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    http.Response response = await http.get(
        '$apiBaseURL/Client/GetClientBasic?clientId=${prefs.getString('clientID')}',
        headers: {
          'Content-Type': 'application/json',
          HttpHeaders.authorizationHeader:
              'AuthFinWs token="${jsonDecode(prefs.getString('user'))['SessionToken']}"'
        });
    print(response.body);
    return jsonDecode(response.body);
  }
}
