import 'dart:io';
import 'dart:convert';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _productName;
  int _selectedIndex = 0;
  List<String> _productsHist = [];

  @override
  void initState() {
    loadProductHist();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BACOFLEA'),
      ),
      body: (_selectedIndex == 0) ? searchBody() : launchBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            title: Text('History'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.launch),
            title: Text('Launch'),
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          searchProductName();
        },
        tooltip: 'scan the barcode',
        child: Icon(Icons.add_a_photo),
      ),
    );
  }

  void _onItemTapped(int index){
    setState(() {_selectedIndex = index;});
  }
  Widget searchBody() {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(10.0),
        ),
        Text('バーコード読み込み履歴'),
        Padding(
          padding: EdgeInsets.all(10.0),
        ),
        RaisedButton.icon(
          icon: Icon(Icons.delete),
          label: Text('履歴消去'),
          onPressed: (){
            setState(() {
              this._productsHist = [];
            });
            saveProductsHist();
          },
        ),
        Flexible(
        child: ListView.builder(
      itemBuilder: (context, i) {
        if (i.isOdd) return Divider();
        int index = i ~/ 2;
        return ListTile(
          leading: Icon(Icons.history),
          title: Text(_productsHist[index]),
          onTap: (){
            setState(() {
              Clipboard.setData(ClipboardData(text: this._productsHist[index]));
              _showDialog('コピーしました', this._productsHist[index]);
            });
          },
        );
      },
      itemCount: _productsHist.length * 2,
        ),
        ),
      ],
    );
  }

  Widget launchBody() {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(10.0),
        ),
        Text('起動サイト一覧'),
        Padding(
          padding: EdgeInsets.all(10.0),
        ),
        ListTile(
          leading: Image.asset('images/mercari_icon.png'),
          title: Text('メルカリ'),
          subtitle: Text('https://www.mercari.com/jp/'),
          onTap: (){
            launchUrl('https://mercari.jp/');
          },
        ),
        ListTile(
          leading: Image.asset('images/rakuma_icon.png'),
          title: Text('ラクマ'),
          subtitle: Text('https://fril.jp/'),
          onTap: (){
            launchUrl('https://fril.jp/');
          },
        ),
        ListTile(
          leading: Image.asset('images/paypay_icon.png'),
          title: Text('PayPayフリマ'),
          subtitle: Text('https://paypayfleamarket.yahoo.co.jp/'),
          onTap: (){
            launchUrl('https://paypayfleamarket.yahoo.co.jp/');
          },
        ),
        ListTile(
          leading: Image.asset('images/bookoff_icon.png'),
          title: Text('BOOK OFF Online'),
          subtitle: Text('https://www.bookoffonline.co.jp/'),
          onTap: (){
            launchUrl('https://www.bookoffonline.co.jp/');
          },
        ),
      ],
    );

  }

  Future searchProductName() async {
    this._productName = '';
    BarcodeScanning scanning = new BarcodeScanning();
    ProductSearcher searcher = new ProductSearcher();
    try{
      await scanning.scan();
      if(scanning.scanStatus == scanning.SCAN_OK){
        await searcher.search(scanning.barcode);
        setState(() => this._productName = searcher.productName);
        await Clipboard.setData(ClipboardData(text: this._productName));
        setState(() {
          this._productsHist.insert(0, this._productName);
          if(10 < this._productsHist.length){
            this._productsHist.removeLast();
          }
        });
        saveProductsHist();
        _showDialog('コピーしました', this._productName);
      }
      else if(scanning.scanStatus() == scanning.CAMERA_ACCESS_DENIED){
        _showDialog('スキャンに失敗しました', 'カメラのアクセスを許可してください');
      }
      else if(scanning.scanStatus() == scanning.UNMATCH_FORMAT){
        _showDialog('スキャンに失敗しました', 'バーコードの種類が異なります');
      }
      else if(scanning.scanStatus() == scanning.UNKNOWN_ERROR){
        _showDialog('スキャンに失敗しました', 'もう一度スキャンしてください');
      }
    } catch (e){
      _showDialog('検索できませんでした', 'もう一度行ってください');
    }
  }

  void _showDialog(String title, String subTitle){
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.info, color: Colors.blue,),
                  Text(title),
                ],
              ),
            ],
          ),
          content: Text(subTitle),
          actions: <Widget>[
            FlatButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void saveProductsHist() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('products_hist', this._productsHist);
  }

  void loadProductHist() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      this._productsHist = (prefs.getStringList('products_hist') ?? new List<String>());
    });
  }
}

class BarcodeScanning{
  String _barcode;
  int _scanStatus;

  int SCAN_OK = 0;
  int CAMERA_ACCESS_DENIED = 1;
  int UNMATCH_FORMAT = 2;
  int UNKNOWN_ERROR = 255;

  get barcode => _barcode;
  get scanStatus => _scanStatus;

  BarcodeScanning(){
    this._barcode = '';
  }

  Future scan() async {
    this._scanStatus = this.UNKNOWN_ERROR;
    try {
      this._barcode = await BarcodeScanner.scan();
      if((this._barcode[0] != '9') || (this.barcode[1] != '7')){
        this._scanStatus = UNMATCH_FORMAT;
      }
      else{
        this._scanStatus = SCAN_OK;
      }
    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.CameraAccessDenied) {
        this._scanStatus = this.CAMERA_ACCESS_DENIED;
      }
    } catch (e) {
    }
  }
}

class ProductSearcher{
  String _clientId;
  String _productName;
  get productName => _productName;

  ProductSearcher(){
    this._clientId = 'CLIENT_ID';
  }

  Future search(String janCode) async {
    try {
      this._productName = '';
      String url = 'https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch';
      url += '?appid=' + this._clientId + '&jan_code=' + janCode + '&results=1';

      var req = await HttpClient().getUrl(Uri.parse(url));
      var res = await req.close();
      String resText = await utf8.decodeStream(res);
      var resJson = jsonDecode(resText);
      this._productName = resJson['hits'][0]['name'];
    } catch (e) {
    }
  }
}
