import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:istanbul_nobetci_eczane/models/eczane.dart';
import 'package:geolocator/geolocator.dart';

class Http {
  static final Map<String, String> _istanbulsaglikGovTrHeaders =
      <String, String>{
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0',
    'Host': 'apps.istanbulsaglik.gov.tr',
    'Origin': 'https://apps.istanbulsaglik.gov.tr',
    'Referer': ' https://apps.istanbulsaglik.gov.tr/NobetciEczane/',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'text/html, */*; q=0.01'
  };

  static Future<String> istanbulsaglikGovTrHtml(String ilce) async {
    try {
      final http.Response response = await http.post(
          'https://apps.istanbulsaglik.gov.tr/NobetciEczane/Home/GetEczaneler',
          headers: _istanbulsaglikGovTrHeaders,
          body: 'ilce=$ilce');
      return response.body;
    } catch (e) {
      throw e;
    }
  }

  static Future<String> postaKoduAraComHtml(String postaKodu) async {
    try {
      final response =
          await http.get('http://www.postakoduara.com/$postaKodu/');
      return response.body;
    } catch (e) {
      throw e;
    }
  }
}

class Parse {
  static Future<String> ilce(String html) async {
    try {
      final document = parse(html);
      final List<String> _tmp =
          document.querySelector('div#orta > span.orta-sonuc').text.split(',');
      return _tmp[_tmp.length - 2].trim();
    } catch (e) {
      throw e;
    }
  }

  static Future<List<Eczane>> eczaneler(String html) async {
    try {
      final List<Eczane> _eczaneler = [];
      final document = parse(html);
      double enDusukKonumFarki = -1.0;
      double konumFarki;
      final baslik = document
          .getElementsByClassName('col-md-4')[0]
          .getElementsByClassName('card-header')[0]
          .text
          .trim();
      document.getElementsByClassName('col-md-4').forEach((col) {
        final String eczaneAdi =
            col.getElementsByClassName('card-header')[1].text.trim();
        final String tel =
            col.querySelectorAll('div.card-body a')[1].text.trim();
        final String sgk = col.querySelector('.badge').text.trim();
        final String adres =
            col.getElementsByTagName('label').elementAt(7).text.trim();
        final String tarif =
            col.getElementsByTagName('label').elementAt(9).text.trim();

        final double lat =
            double.parse(col.innerHtml.split('?lat=')[1].split('&')[0]);
        final double lon =
            double.parse(col.innerHtml.split(';lon=')[1].split('&')[0]);

        final List<double> sonuc =
            _enDusukKonumFarki(lat, lon, enDusukKonumFarki);

        konumFarki = sonuc[0];
        enDusukKonumFarki = sonuc[1];

        _eczaneler.add(
          Eczane.name(
            eczaneAdi: eczaneAdi,
            telefon: "$tel  SGK: $sgk",
            tarif: '$tarif',
            adres: 'Adres: $adres',
            baslik: baslik,
            lat: lat,
            lon: lon,
            konumFarki: konumFarki,
          ),
        );
      });
      _eczaneler
          .firstWhere((ecz) => ecz.konumFarki == enDusukKonumFarki)
          .enYakinEczane = true;
      return _eczaneler;
    } catch (e) {
      throw e;
    }
  }

  static List<double> _enDusukKonumFarki(
      double lat, double lon, double enDusukKonumFarki) {
    double _latitude = (GeolocatorEngine.latitude - lat);
    double _longitude = (GeolocatorEngine.longitude - lon);
    final sonuc = new List<double>();
    if (_latitude < 0) {
      _latitude = -1.0 * _latitude;
    }
    if (_longitude < 0) {
      _longitude = -1.0 * _longitude;
    }
    double konumFark = _latitude + _longitude;
    sonuc.add(konumFark);
    sonuc.add((enDusukKonumFarki == -1.0 || konumFark < enDusukKonumFarki)
        ? konumFark
        : enDusukKonumFarki);

    return sonuc;
  }
}

class GeolocatorEngine {
  static final Geolocator _geolocator = Geolocator()
    ..forceAndroidLocationManager;

  static double latitude;
  static double longitude;

  static Future<String> currentPostalCode() async {
    if (!(await _geolocator.isLocationServiceEnabled())) {
      throw Exception('Konum servisiniz kapalı!');
    }

    try {
      Position _position = await _geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      latitude = _position.latitude;
      longitude = _position.longitude;

      List<Placemark> p = await _geolocator.placemarkFromCoordinates(
          _position.latitude, _position.longitude);
      Placemark place = p[0];
      return place.postalCode;
    } catch (e) {
      throw e;
    }
  }
}
