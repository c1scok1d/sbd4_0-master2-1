import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:businesslistingapi/config/ps_colors.dart';
import 'package:businesslistingapi/constant/ps_constants.dart';
import 'package:businesslistingapi/constant/ps_dimens.dart';
import 'package:businesslistingapi/ui/common/base/ps_widget_with_appbar_with_no_provider.dart';
import 'package:businesslistingapi/utils/utils.dart';
import 'package:businesslistingapi/viewobject/holder/intent_holder/map_pin_call_back_holder.dart';
import 'package:geocoder/geocoder.dart';
import 'package:latlong/latlong.dart';

class MapPinView extends StatefulWidget {
  const MapPinView(
      {@required this.flag, @required this.maplat, @required this.maplng});

  final String flag;
  final String maplat;
  final String maplng;

  @override
  _MapPinViewState createState() => _MapPinViewState();
}

class _MapPinViewState extends State<MapPinView> with TickerProviderStateMixin {
  LatLng latlng;
  double defaultRadius = 3000;
  String address = '';

  dynamic loadAddress() async {
    final List<Address> addresses = await Geocoder.local
        .findAddressesFromCoordinates(
            Coordinates(latlng.latitude, latlng.longitude));
    final Address first = addresses.first;
    address = '${first.addressLine}  \n, ${first.countryName}';
  }

  @override
  Widget build(BuildContext context) {
    latlng ??= LatLng(double.parse(widget.maplat), double.parse(widget.maplng));

    final double scale = defaultRadius / 200; //radius/20
    final double value = 16 - log(scale) / log(2);
    loadAddress();

    print('value $value');

    return PsWidgetWithAppBarWithNoProvider(
        appBarTitle: Utils.getString(context, 'map_pin__title'),
        actions: widget.flag == PsConst.PIN_MAP
            ? <Widget>[
                InkWell(
                  child: Ink(
                    child: Center(
                      child: Text(
                        'PICKLOCATION',
                        textAlign: TextAlign.justify,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2
                            .copyWith(fontWeight: FontWeight.bold)
                            .copyWith(color: PsColors.mainColor),
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context,
                        MapPinCallBackHolder(address: address, latLng: latlng));
                  },
                ),
                const SizedBox(
                  width: PsDimens.space16,
                ),
              ]
            : <Widget>[],
        child: Scaffold(
          body: Column(
            children: <Widget>[
              Flexible(
                child: FlutterMap(
                  options: MapOptions(
                      center:
                          latlng, //LatLng(51.5, -0.09), //LatLng(45.5231, -122.6765),
                      zoom: value, //10.0,
                      onTap: widget.flag == PsConst.PIN_MAP
                          ? _handleTap
                          : _doNothingTap),
                  layers: <LayerOptions>[
                    TileLayerOptions(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayerOptions(markers: <Marker>[
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: latlng,
                        builder: (BuildContext ctx) => Container(
                          child: IconButton(
                            icon: Icon(
                              Icons.location_on,
                              color: PsColors.mainColor,
                            ),
                            iconSize: 45,
                            onPressed: () {},
                          ),
                        ),
                      )
                    ])
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  void _handleTap(LatLng latlng) {
    setState(() {
      this.latlng = latlng;
    });
  }

  void _doNothingTap(LatLng latlng) {}
}
