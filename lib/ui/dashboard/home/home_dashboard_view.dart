import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:businesslistingapi/api/common/ps_resource.dart';
import 'package:businesslistingapi/api/common/ps_status.dart';
import 'package:businesslistingapi/config/ps_colors.dart';
import 'package:businesslistingapi/config/ps_config.dart';
import 'package:businesslistingapi/constant/ps_constants.dart';
import 'package:businesslistingapi/constant/ps_dimens.dart';
import 'package:businesslistingapi/constant/route_paths.dart';
import 'package:businesslistingapi/db/common/ps_shared_preferences.dart';
import 'package:businesslistingapi/models/simple_geofence.dart';
import 'package:businesslistingapi/provider/blog/blog_provider.dart';
import 'package:businesslistingapi/provider/city/city_provider.dart';
import 'package:businesslistingapi/provider/city/popular_city_provider.dart';
import 'package:businesslistingapi/provider/city/recommanded_city_provider.dart';
import 'package:businesslistingapi/provider/item/discount_item_provider.dart';
import 'package:businesslistingapi/provider/item/feature_item_provider.dart';
import 'package:businesslistingapi/provider/item/item_provider.dart';
import 'package:businesslistingapi/provider/item/near_me_item_provider.dart';
import 'package:businesslistingapi/provider/item/search_item_provider.dart';
import 'package:businesslistingapi/provider/item/trending_item_provider.dart';
import 'package:businesslistingapi/repository/blog_repository.dart';
import 'package:businesslistingapi/repository/category_repository.dart';
import 'package:businesslistingapi/repository/city_repository.dart';
import 'package:businesslistingapi/repository/item_collection_repository.dart';
import 'package:businesslistingapi/repository/item_repository.dart';
import 'package:businesslistingapi/ui/city/item/city_horizontal_list_item.dart';
import 'package:businesslistingapi/ui/city/item/popular_city_horizontal_list_item.dart';
import 'package:businesslistingapi/ui/common/dialog/confirm_dialog_view.dart';
import 'package:businesslistingapi/ui/common/dialog/error_dialog.dart';
import 'package:businesslistingapi/ui/common/dialog/noti_dialog.dart';
import 'package:businesslistingapi/ui/common/dialog/rating_dialog/core.dart';
import 'package:businesslistingapi/ui/common/dialog/rating_dialog/style.dart';
import 'package:businesslistingapi/ui/common/ps_admob_banner_widget.dart';
import 'package:businesslistingapi/ui/common/ps_frame_loading_widget.dart';
import 'package:businesslistingapi/ui/common/ps_textfield_widget_with_icon.dart';
import 'package:businesslistingapi/ui/dashboard/core/dashboard_view.dart';
import 'package:businesslistingapi/ui/dashboard/home/blog_slider.dart';
import 'package:businesslistingapi/ui/items/detail/item_detail_view.dart';
import 'package:businesslistingapi/ui/items/item/item_horizontal_list_item.dart';
import 'package:businesslistingapi/utils/save_file.dart';
import 'package:businesslistingapi/utils/utils.dart';
import 'package:businesslistingapi/viewobject/blog.dart';
import 'package:businesslistingapi/viewobject/city.dart';
import 'package:businesslistingapi/viewobject/common/ps_value_holder.dart';
import 'package:businesslistingapi/viewobject/holder/city_parameter_holder.dart';
import 'package:businesslistingapi/viewobject/holder/intent_holder/city_intent_holder.dart';
import 'package:businesslistingapi/viewobject/holder/intent_holder/item_detail_intent_holder.dart';
import 'package:businesslistingapi/viewobject/holder/intent_holder/item_entry_intent_holder.dart';
import 'package:businesslistingapi/viewobject/holder/intent_holder/item_list_intent_holder.dart';
import 'package:businesslistingapi/viewobject/holder/item_parameter_holder.dart';
import 'package:businesslistingapi/viewobject/item.dart';
import 'package:businesslistingapi/viewobject/item_collection_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofence/geofence.dart' as geo;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_admob/flutter_native_admob.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class HomeDashboardViewWidget extends StatefulWidget {
  const HomeDashboardViewWidget(
      this._scrollController,
      this.animationController,
      this.context,
      this.animationControllerForFab,
      this.onNotiClicked);

  final ScrollController _scrollController;
  final AnimationController animationController;
  final AnimationController animationControllerForFab;
  final BuildContext context;

  final Function onNotiClicked;

  @override
  _HomeDashboardViewWidgetState createState() =>
      _HomeDashboardViewWidgetState();
}

class _HomeDashboardViewWidgetState extends State<HomeDashboardViewWidget> {
  PsValueHolder valueHolder;
  CategoryRepository categoryRepo;
  ItemRepository itemRepo;
  CityRepository cityRepo;
  BlogRepository blogRepo;
  ItemCollectionRepository itemCollectionRepo;
  BlogProvider _blogProvider;
  SearchItemProvider _searchItemProvider;
  TrendingItemProvider _trendingItemProvider;
  FeaturedItemProvider _featuredItemProvider;
  NearMeItemProvider _nearMeItemProvider;
  DiscountItemProvider _discountItemProvider;
  PopularCityProvider _popularCityProvider;
  CityProvider _cityProvider;
  RecommandedCityProvider _recommandedCityProvider;
  geo.Coordinate globalCoordinate;
  final int count = 8;
  var _geofenceService;
  final RateMyApp _rateMyApp = RateMyApp(
      preferencesPrefix: 'rateMyApp_',
      minDays: 0,
      minLaunches: 1,
      remindDays: 5,
      remindLaunches: 1);

  @override
  Future<void> initState() {
    super.initState();
    print('InitState');
    if (Platform.isAndroid) {
      _rateMyApp.init().then((_) {
        if (_rateMyApp.shouldOpenDialog) {
          _rateMyApp.showStarRateDialog(
            context,
            title: Utils.getString(context, 'home__menu_drawer_rate_this_app'),
            message: Utils.getString(context, 'rating_popup_dialog_message'),
            ignoreNativeDialog: true,
            actionsBuilder: (BuildContext context, double stars) {
              return <Widget>[
                TextButton(
                  child: Text(
                    Utils.getString(context, 'dialog__ok'),
                  ),
                  onPressed: () async {
                    if (stars != null) {
                      // _rateMyApp.save().then((void v) => Navigator.pop(context));
                      Navigator.pop(context);
                      if (stars <= 3) {
                        await _rateMyApp
                            .callEvent(RateMyAppEventType.laterButtonPressed);
                        await showDialog<dynamic>(
                            context: context,
                            builder: (BuildContext context) {
                              return ConfirmDialogView(
                                description: Utils.getString(
                                    context, 'rating_confirm_message'),
                                leftButtonText:
                                    Utils.getString(context, 'dialog__cancel'),
                                rightButtonText:
                                    Utils.getString(context, 'dialog__ok'),
                                onAgreeTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                    context,
                                    RoutePaths.contactUs,
                                  );
                                },
                              );
                            });
                      } else if (stars >= 4) {
                        await _rateMyApp
                            .callEvent(RateMyAppEventType.rateButtonPressed);
                        if (Platform.isIOS) {
                          Utils.launchAppStoreURL(
                              iOSAppId: PsConfig.iOSAppStoreId,
                              writeReview: true);
                        } else {
                          Utils.launchURL();
                        }
                      }
                    } else {
                      Navigator.pop(context);
                    }
                  },
                )
              ];
            },
            onDismissed: () =>
                _rateMyApp.callEvent(RateMyAppEventType.laterButtonPressed),
            dialogStyle: const DialogStyle(
              titleAlign: TextAlign.center,
              messageAlign: TextAlign.center,
              messagePadding: EdgeInsets.only(bottom: 16.0),
            ),
            starRatingOptions: const StarRatingOptions(),
          );
        }
      });
    }
    // Create a [GeofenceService] instance and set options.
     _geofenceService = GeofenceService.instance.setup(
        interval: 5000,
        accuracy: 100,
        loiteringDelayMs: 60000,
        statusChangeDelayMs: 10000,
        useActivityRecognition: true,
        allowMockLocations: false,
        printDevLog: false,
        geofenceRadiusSortType: GeofenceRadiusSortType.DESC);

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addLocationServicesStatusChangeListener(_onLocationServicesStatusChanged);
      _geofenceService.addActivityChangeListener(_onActivityChanged);
      _geofenceService.addStreamErrorListener(_onError);
    });
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('launcher_icon');
    var initializationSettingsIOS =
        IOSInitializationSettings(onDidReceiveLocalNotification: null);
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

// You can can also directly ask the permission about its status.
//     if (await Permission.location.isRestricted) {
//       // The OS restricts access, for example because of parental controls.
//     }
  }

  Future<void> onSelectNotification(String payload) async {
    if (context == null) {
      widget.onNotiClicked(payload);
    } else {
      if(payload.contains('Item x')){
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => DashboardView()),
        );
      }else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (context) => ItemDetailView(itemId: payload,)),
        );
      }
    }
  }

  final TextEditingController userInputItemNameTextEditingController =
      TextEditingController();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      new FlutterLocalNotificationsPlugin();
  bool hasAlreadyListened = false;

  @override
  Widget build(BuildContext context) {
    categoryRepo = Provider.of<CategoryRepository>(context);
    itemRepo = Provider.of<ItemRepository>(context);
    cityRepo = Provider.of<CityRepository>(context);
    blogRepo = Provider.of<BlogRepository>(context);
    itemCollectionRepo = Provider.of<ItemCollectionRepository>(context);
    valueHolder = Provider.of<PsValueHolder>(context);

    print('HOME NOW');

    initPlatformState();
    return MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<BlogProvider>(
              lazy: false,
              create: (BuildContext context) {
                _blogProvider = BlogProvider(
                    repo: blogRepo, limit: PsConfig.BLOG_ITEM_LOADING_LIMIT);
                _blogProvider.loadBlogList();

                return _blogProvider;
              }),
          ChangeNotifierProvider<SearchItemProvider>(
              lazy: false,
              create: (BuildContext context) {
                _searchItemProvider = SearchItemProvider(
                    repo: itemRepo,
                    limit: PsConfig.LATEST_PRODUCT_LOADING_LIMIT);
                _searchItemProvider.loadItemListByKey(
                    ItemParameterHolder().getLatestParameterHolder());
                return _searchItemProvider;
              }),
          ChangeNotifierProvider<TrendingItemProvider>(
              lazy: false,
              create: (BuildContext context) {
                _trendingItemProvider = TrendingItemProvider(
                    repo: itemRepo,
                    limit: PsConfig.TRENDING_PRODUCT_LOADING_LIMIT);
                _trendingItemProvider.loadItemList(PsConst.PROPULAR_ITEM_COUNT,
                    ItemParameterHolder().getTrendingParameterHolder());
                return _trendingItemProvider;
              }),
          ChangeNotifierProvider<FeaturedItemProvider>(
              lazy: false,
              create: (BuildContext context) {
                _featuredItemProvider = FeaturedItemProvider(
                    repo: itemRepo,
                    limit: PsConfig.FEATURE_PRODUCT_LOADING_LIMIT);
                _featuredItemProvider.loadItemList(
                    ItemParameterHolder().getFeaturedParameterHolder());
                return _featuredItemProvider;
              }),
          ChangeNotifierProvider<NearMeItemProvider>(
              lazy: false,
              create: (BuildContext context) {
                _nearMeItemProvider = NearMeItemProvider(
                    repo: itemRepo,
                    limit: PsConfig.FEATURE_PRODUCT_LOADING_LIMIT);
                // globalgeo.Coordinate=Entypo.awareness_ribbon

                _nearMeItemProvider.loadItemList(globalCoordinate);
                return _nearMeItemProvider;
              }),
          ChangeNotifierProvider<DiscountItemProvider>(
              lazy: false,
              create: (BuildContext context) {
                _discountItemProvider = DiscountItemProvider(
                    repo: itemRepo,
                    limit: PsConfig.DISCOUNT_PRODUCT_LOADING_LIMIT);
                _discountItemProvider.loadItemList(
                    ItemParameterHolder().getDiscountParameterHolder());
                return _discountItemProvider;
              }),
          ChangeNotifierProvider<PopularCityProvider>(
              lazy: false,
              create: (BuildContext context) {
                _popularCityProvider = PopularCityProvider(
                    repo: cityRepo, limit: PsConfig.POPULAR_CITY_LOADING_LIMIT);
                _popularCityProvider
                    .loadPopularCityList()
                    .then((dynamic value) {
                  // Utils.psPrint("Is Has Internet " + value);
                  final bool isConnectedToIntenet = value ?? bool;
                  if (!isConnectedToIntenet) {
                    Fluttertoast.showToast(
                        msg: 'No Internet Connection. Please try again !',
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.blueGrey,
                        textColor: Colors.white);
                  }
                });

                return _popularCityProvider;
              }),
          ChangeNotifierProvider<CityProvider>(
              lazy: false,
              create: (BuildContext context) {
                _cityProvider = CityProvider(
                    repo: cityRepo, limit: PsConfig.NEW_CITY_LOADING_LIMIT);
                _cityProvider
                    .loadCityListByKey(CityParameterHolder().getRecentCities());
                return _cityProvider;
              }),
          ChangeNotifierProvider<RecommandedCityProvider>(
              lazy: false,
              create: (BuildContext context) {
                _recommandedCityProvider = RecommandedCityProvider(
                    repo: cityRepo,
                    limit: PsConfig.RECOMMAND_CITY_LOADING_LIMIT);
                _recommandedCityProvider.loadRecommandedCityList();
                return _recommandedCityProvider;
              }),
        ],
        child: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                if (await Utils.checkInternetConnectivity()) {
                  Utils.navigateOnUserVerificationView(context, () async {
                    Navigator.pushNamed(context, RoutePaths.itemEntry,
                        arguments: ItemEntryIntentHolder(
                            flag: PsConst.ADD_NEW_ITEM, item: Item()));
                  });
                } else {
                  showDialog<dynamic>(
                      context: context,
                      builder: (BuildContext context) {
                        return ErrorDialog(
                          message: Utils.getString(
                              context, 'error_dialog__no_internet'),
                        );
                      });
                }
              },
              child: Icon(Icons.add, color: PsColors.white),
              backgroundColor: PsColors.mainColor,
              // label: Text(Utils.getString(context, 'dashboard__submit_ad'),
              //     style: Theme.of(context)
              //         .textTheme
              //         .caption
              //         .copyWith(color: PsColors.white)),
            ),
            body: WillStartForegroundTask(
                onWillStart: () async {
                  // You can add a foreground task start condition.
                  return _geofenceService.isRunningService;
                },
                androidNotificationOptions: const AndroidNotificationOptions(
                  channelId: 'geofence_service_notification_channel',
                  channelName: 'Geofence Service Notification',
                  channelDescription: 'This notification appears when the geofence service is running in the background.',
                  channelImportance: NotificationChannelImportance.HIGH,
                  priority: NotificationPriority.HIGH,
                  isSticky: false,
                ),
                iosNotificationOptions: const IOSNotificationOptions(),
                notificationTitle: 'Geofence Service is running',
                notificationText: 'Tap to return to the app',
                child:Container(
                  color: PsColors.coreBackgroundColor,
                  child: RefreshIndicator(
                    onRefresh: () {
                      _blogProvider.resetBlogList();
                      _searchItemProvider.resetLatestItemList(
                          ItemParameterHolder().getLatestParameterHolder());
                      _trendingItemProvider.resetTrendingItemList(
                          ItemParameterHolder().getTrendingParameterHolder());
                      _featuredItemProvider.resetFeatureItemList(
                          ItemParameterHolder().getFeaturedParameterHolder());
                      _nearMeItemProvider.resetNearMeItemList(globalCoordinate);
                      _discountItemProvider.resetDiscountItemList(
                          ItemParameterHolder().getDiscountParameterHolder());
                      _popularCityProvider
                          .resetPopularCityList()
                          .then((dynamic value) {
                        // Utils.psPrint("Is Has Internet " + value);
                        final bool isConnectedToIntenet = value ?? bool;
                        if (!isConnectedToIntenet) {
                          Fluttertoast.showToast(
                              msg: 'No Internet Connection. Please try again !',
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.blueGrey,
                              textColor: Colors.white);
                        }
                      });
                      _cityProvider.resetCityListByKey(
                          CityParameterHolder().getRecentCities());
                      return _recommandedCityProvider.resetRecommandedCityList();
                    },
                    child: CustomScrollView(
                      controller: widget._scrollController,
                      scrollDirection: Axis.vertical,
                      slivers: <Widget>[
                        _MyHomeHeaderWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 1, 1.0,
                                      curve: Curves.fastOutSlowIn))),
                          userInputItemNameTextEditingController:
                          userInputItemNameTextEditingController,
                          psValueHolder: valueHolder, //animation
                        ),
                        _HomeFeaturedItemHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 3, 1.0,
                                      curve: Curves.fastOutSlowIn))),
                        ),
                        _HomeNearMeItemHorizontalListWidget(
                          globalCoordinate: globalCoordinate,
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 3, 1.0,
                                      curve: Curves.fastOutSlowIn))),
                        ),
                        _HomePopularCityHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 2, 1.0,
                                      curve: Curves.fastOutSlowIn))),
                        ),
                        _HomeRecommandedCityHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 4, 1.0,
                                      curve: Curves.fastOutSlowIn))),
                        ),
                        _HomeNewCityHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 6, 1.0,
                                      curve: Curves.fastOutSlowIn))), //animation
                        ),
                        _HomeBlogSliderWidget(
                          animationController: widget.animationController,

                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 7, 1.0,
                                      curve: Curves.fastOutSlowIn))), //animation
                        ),
                        _HomeTrendingItemHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 5, 1.0,
                                      curve: Curves.fastOutSlowIn))), //animation
                        ),
                        _HomeNewPlaceHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 4, 1.0,
                                      curve: Curves.fastOutSlowIn))), //animation
                        ),
                        _HomeOnPromotionHorizontalListWidget(
                          animationController: widget.animationController,
                          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: widget.animationController,
                                  curve: Interval((1 / count) * 3, 1.0,
                                      curve: Curves.fastOutSlowIn))), //animation
                        ),
                      ],
                    ),
                  ),
                )
            ),
            ));
  }
// This function is to be called when the geofence status is changed.
  Future<void> _onGeofenceStatusChanged(
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus geofenceStatus,
      Location location) async {
    print('geofence: ${geofence.toJson()}');
    print('geofenceRadius: ${geofenceRadius.toJson()}');
    print('geofenceStatus: ${geofenceStatus.toString()}');
    actOnGeofence(geofenceStatus,geofence);
    // _geofenceStreamController.sink.add(geofence);
  }

// This function is to be called when the activity has changed.
  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('prevActivity: ${prevActivity.toJson()}');
    print('currActivity: ${currActivity.toJson()}');
    // _activityStreamController.sink.add(currActivity);
  }

// This function is to be called when the location has changed.
  void _onLocationChanged(Location location) {
    print('location: ${location.toJson()}');
  }

// This function is to be called when a location services status change occurs
// since the service was started.
  void _onLocationServicesStatusChanged(bool status) {
    print('isLocationServicesEnabled: $status');
  }

// This function is used to handle errors that occur in the service.
  void _onError(error) {
    final errorCode = getErrorCodesFromError(error);
    if (errorCode == null) {
      print('Undefined error: $error');
      return;
    }

    print('ErrorCode: $errorCode');
  }

  Future<void> startBackgroundTracking(geo.Coordinate globalCoordinate) async {
    print('$TAG startBackgroundTracking');
    await requestPermission();

    final SearchItemProvider provider =
        SearchItemProvider(repo: itemRepo, psValueHolder: valueHolder);
    final ItemParameterHolder itemParameterHolder = ItemParameterHolder();
    final bool isConnectedToInternet = await Utils.checkInternetConnectivity();
    final StreamController<PsResource<List<Item>>> itemListStream =
        StreamController<PsResource<List<Item>>>.broadcast();
    itemListStream.stream.listen((PsResource<List<Item>> event) {
      print('Fetch some items ${event.data.length}');
      registerGeofences(event);
    });

    itemRepo.getItemListByLoc(
        itemListStream,
        isConnectedToInternet,
        30,
        0,
        PsStatus.PROGRESS_LOADING,
        globalCoordinate.latitude,
        globalCoordinate.longitude,
        PsConst.RADIUS,
        itemParameterHolder.getSearchParameterHolder());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    if (hasAlreadyListened)
      return;
    print('😡 initPlatform state');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted)
      return;
    //PsSharedPreferences _psSharedPreferences;
    final SharedPreferences sharedPreferences =
    await PsSharedPreferences.instance.futureShared;

    // permission check
    await requestPermission();
    geo.Geofence.initialize();
    geo.Geofence.requestPermissions();
    globalCoordinate = await geo.Geofence.getCurrentLocation();
    // if permission check good start geoNotifications
    bool isEnabled = sharedPreferences.getBool(PsConst.GEO_SERVICE_KEY);
    if(isEnabled){
      startBackgroundTracking(globalCoordinate);
      print('$TAG Your latitude is ${globalCoordinate.latitude} and longitude ${globalCoordinate.longitude}');
    }
    //Will be handles by handler
    // geo.Coordinate globalCoordinate = await Geofence.g;
    setState(() {
      _nearMeItemProvider.resetNearMeItemList(globalCoordinate);
      //globalCoordinate = c;
    });
    setState(() {});
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  static final double GEOFENCE_EXPIRATION_IN_HOURS = 12;
  static final double GEOFENCE_EXPIRATION_IN_MILLISECONDS =
      GEOFENCE_EXPIRATION_IN_HOURS * 60 * 60 * 1000;
  static HashMap<String, SimpleGeofence> geofences =
      HashMap<String, SimpleGeofence>();

  void registerGeofences(PsResource<List<Item>> items) {
    print('$TAG RegisterGeofences ${items.data.first.paidStatus}');
    for (Item i in items.data) {
      if (i.isPaid == '1') {
        geofences.putIfAbsent(
            i.id,
                () =>
                SimpleGeofence(
                    i.id,
                    double.parse(i.lat),
                    double.parse(i.lng),
                    i.isFeatured,
                    i.isPromotion,
                    i.cityId,
                    i.name,
                    i.defaultPhoto?.imgPath,
                    [GeofenceRadius(id: i.id,length: 5000)],
                    GEOFENCE_EXPIRATION_IN_MILLISECONDS,
                    GeofenceStatus.DWELL));
      } else if (i.isFeatured == '1' || i.isPromotion == '1') {
        geofences.putIfAbsent(
            '${i.id}-a',
                () =>
                SimpleGeofence(
                    i.id,
                    double.parse(i.lat),
                    double.parse(i.lng),
                    i.isFeatured,
                    i.isPromotion,
                    i.cityId,
                    i.name,
                    i.defaultPhoto?.imgPath,
                    [GeofenceRadius(id: i.id,length: 5000)],
                    GEOFENCE_EXPIRATION_IN_MILLISECONDS,
                    GeofenceStatus.ENTER));
        geofences.putIfAbsent(
            '${i.id}-b',
                () =>
                SimpleGeofence(
                    i.id,
                    double.parse(i.lat),
                    double.parse(i.lng),
                    i.isFeatured,
                    i.isPromotion,
                    i.cityId,
                    i.name,
                    i.defaultPhoto?.imgPath,
                    [GeofenceRadius(id: i.id,length: 5000)],
                    GEOFENCE_EXPIRATION_IN_MILLISECONDS,
                    GeofenceStatus.EXIT));
      }
    }
    // Geofence.removeAllGeolocations();
    _geofenceService.clearGeofenceList();
    List<Geofence> _geofenceList=[];
    geofences.forEach((key, value) {
      _geofenceList.add(value.toGeofence());
    });

    _geofenceService.start(_geofenceList).catchError(_onError);

  }
  int nearGeofences=0;
  int x = 0;   bool hasDisplayedEnter=false;
  bool hasDisplayedDwell=false;
  bool hasDisplayedExit=false;
  Future<void> actOnGeofence(GeofenceStatus geofenceStatus, Geofence geofence) async {
    print('actOnGeofence');

    final SharedPreferences sharedPreferences =
        await PsSharedPreferences.instance.futureShared;
    getGeoCity(geofence.id).then((SimpleGeofence c) async {
      if (c == null) {
        print('$TAG Could not set notification, Item not found');
        return;
      }
      if (geofenceStatus == c.transitionType &&
          geofenceStatus == GeofenceStatus.EXIT && c.isfeatured == '1') {
        print('Exiting ${c.item_name}');
          hasDisplayedExit=true;
          scheduleNotification(
              "Don't miss an opportunity to buy black.",
              'You are near ${c.item_name}',
              GeofenceStatus.EXIT,
              paypload: c.id,
              item: c);
        c.transitionType = GeofenceStatus.EXIT;
      }else if (geofenceStatus == c.transitionType &&
          geofenceStatus == GeofenceStatus.DWELL && c.isPromotion == '1') {
        print('Dwelling ${c.item_name}');
          hasDisplayedDwell=true;
          scheduleNotification('You are near ${c.item_name}',
              'Stop in and say Hi!', GeofenceStatus.DWELL,
              paypload: c.id, item: c);
        //}
        c.transitionType = GeofenceStatus.DWELL;
      }else if(geofenceStatus==GeofenceStatus.ENTER){

       /* Uri apiUri = Uri.parse("https://ekzane.com/admin/api/geofencedemo.php");

        final response = await http.post(apiUri);
        if (response.statusCode == 200) {
        }
        else {
          //Show Error Message
        } */

        print('Entering ${c.item_name}');
        nearGeofences++;
        String firstName = '';
        try {
          firstName = sharedPreferences
              .getString(PsConst.VALUE_HOLDER__USER_NAME);
          firstName ??= '';
        } on Exception catch (e) {
          print('$TAG Could not get the name');
        }
      }

      if(!hasDisplayedEnter){
        hasDisplayedEnter=true;
        PsSharedPreferences.instance.futureShared.then((sharedPreferences) {

          String firstName = '';
          try {
            firstName = sharedPreferences
                .getString(PsConst.VALUE_HOLDER__USER_NAME);
            firstName ??= '';
          } on Exception catch (e) {
            print('$TAG Could not get the name');
          }
          if(sharedPreferences.getString(PsConst.VALUE_HOLDER__USER_NAME) != '' && sharedPreferences.getString(PsConst.VALUE_HOLDER__USER_NAME) != null) {
            int timestamp = DateTime.now().millisecondsSinceEpoch;
            sharedPreferences.setInt('LAST_NOT_TIME', timestamp);
            scheduleNotification(
                'Good news '+sharedPreferences.getString(PsConst.VALUE_HOLDER__USER_NAME),
                'There are '+nearGeofences.toString()+' black owned businesses near you!',
                GeofenceStatus.ENTER);
          } else {
            int timestamp = DateTime.now().millisecondsSinceEpoch;
            sharedPreferences.setInt('LAST_NOT_TIME', timestamp);
            scheduleNotification(
              'Good news',
              'There are  '+nearGeofences.toString()+' black owned businesses near you!',
              GeofenceStatus.ENTER,);
          }
        });


      }
    });

  }

  static String TAG = 'GEOFENCES NEW:';

  Future<void> scheduleNotification(
      String title, String subtitle, GeofenceStatus event,
      {String paypload = "Item x", SimpleGeofence item}) async {
    print("$TAG scheduling one with $title and $subtitle");
    // var rng = new Random();
    // Future.delayed(Duration(seconds: 5)).then((value) => null);
    // Bitmap bitmap = await Bitmap.fromProvider(NetworkImage(PsConfig.ps_app_image_url+city.defaultPhoto.imgPath));

    Future.delayed(const Duration(seconds: 5), () {}).then((result) async {
      if (item==null||item.imageId == null) {
        final androidPlatformChannelSpecifics =
            const AndroidNotificationDetails(
                '1123', 'Geofences', 'Geofence alert',
                importance: Importance.high,
                priority: Priority.high,
                ticker: 'ticker');
        final iOSPlatformChannelSpecifics = IOSNotificationDetails();
        final platformChannelSpecifics = NotificationDetails(
            android: androidPlatformChannelSpecifics,
            iOS: iOSPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
            // rng.nextInt(100000), title, subtitle, platformChannelSpecifics,
            1,
            title,
            subtitle,
            platformChannelSpecifics,
            payload: paypload);
      } else {
        var mfile = await SaveFile()
            .saveImage(PsConfig.ps_app_image_url + item.imageId ?? '');
        print(mfile.absolute.path);
        var smallPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(mfile.absolute.path),
            largeIcon: FilePathAndroidBitmap(mfile.absolute.path),
            contentTitle: '$title',
            htmlFormatContentTitle: true,
            summaryText: '$subtitle',
            hideExpandedLargeIcon: true,
            htmlFormatSummaryText: true);
        var bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(mfile.absolute.path),
            largeIcon: FilePathAndroidBitmap(mfile.absolute.path),
            contentTitle: '$title',
            htmlFormatContentTitle: true,
            summaryText: '$subtitle',
            hideExpandedLargeIcon: false,
            htmlFormatSummaryText: true);
        final androidPlatformChannelSpecifics = AndroidNotificationDetails(
            '1123', 'Geofences', 'Geofence alert',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: event==GeofenceStatus.EXIT?smallPictureStyleInformation:bigPictureStyleInformation,
            largeIcon: FilePathAndroidBitmap(mfile.absolute.path),

            ticker: 'ticker');
        final iOSPlatformChannelSpecifics = IOSNotificationDetails(
            attachments: <IOSNotificationAttachment>[
              IOSNotificationAttachment(mfile.absolute.path)
            ]);
        final platformChannelSpecifics = NotificationDetails(
            android: androidPlatformChannelSpecifics,
            iOS: iOSPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
            // rng.nextInt(100000), title, subtitle, platformChannelSpecifics,
            1,
            title,
            subtitle,
            platformChannelSpecifics,
            payload: paypload);
      }
    });
  }

  Future<SimpleGeofence> getGeoCity(String id) {
    print('$TAG getGeoCity ');
    geofences.forEach((key, value) {
      if (key.contains('-')) {
        if (key.split('-')[0] == id) {
          return Future.value(value);
        }
      } else {
        if (key == id) {
          return Future.value(value);
        }
      }
    });
    return Future.value(null);
  }

  Future<void> requestPermission() async {
    print('REQUESTING PERMISSION');
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();
    if (!(statuses[Permission.locationWhenInUse]).isGranted /*&& !(statuses[Permission.locationWhenInUse]).isPermanentlyDenied*/) {
      print(statuses[Permission.locationWhenInUse]);
      if (!(statuses[Permission.locationAlways]).isGranted /*&& !(statuses[Permission.locationAlways]).isPermanentlyDenied*/) {
        Navigator.pushReplacementNamed(
          context,
          RoutePaths.permissionRationale,
        );
      }
    }
  }

  void showDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                    height: 60,
                    width: double.infinity,
                    padding: const EdgeInsets.all(PsDimens.space8),
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5),
                            topRight: Radius.circular(5)),
                        color: PsColors.mainColor),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: PsDimens.space4),
                        Icon(
                          Icons.pin_drop,
                          color: PsColors.white,
                        ),
                        const SizedBox(width: PsDimens.space4),
                        Text(
                          'Special Permission',
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: PsColors.white,
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: PsDimens.space20),
                Container(
                  padding: const EdgeInsets.only(
                      left: PsDimens.space16,
                      right: PsDimens.space16,
                      top: PsDimens.space8,
                      bottom: PsDimens.space8),
                  child: Text(
                    "You will not be alerted when you are near a registered black owned business.\n "
                    "We respect user privacy. You location will never be recorded or shared for any reason.\n "
                    "Tap 'Continue' to proceed without receiving alerts.\n"
                    "To enable alerts when near a registered black owned business select 'allow all the time' at [Go to Settings] > [Permissions]\n"
                    "Tap 'Continue' and select 'Allow all the time' from the next screen to receive alerts.\n",
                    style: Theme.of(context).textTheme.subtitle2,
                  ),
                ),
                const SizedBox(height: PsDimens.space20),
                Divider(
                  thickness: 0.5,
                  height: 1,
                  color: Theme.of(context).iconTheme.color,
                ),
                ButtonBar(
                  children: [
                    MaterialButton(
                      height: 50,
                      minWidth: 100,
                      onPressed: () async {
                        Navigator.of(context).pop();

                        AppSettings.openAppSettings(asAnotherTask: true);
                      },
                      child: Text(
                        'Go to Settings',
                        style: Theme.of(context)
                            .textTheme
                            .button
                            .copyWith(color: PsColors.mainColor),
                      ),
                    ),
                    MaterialButton(
                      height: 50,
                      minWidth: 100,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'No',
                        style: Theme.of(context)
                            .textTheme
                            .button
                            .copyWith(color: PsColors.mainColor),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeFeaturedItemHorizontalListWidget extends StatefulWidget {
  const _HomeFeaturedItemHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeFeaturedItemHorizontalListWidgetState createState() =>
      __HomeFeaturedItemHorizontalListWidgetState();
}

class __HomeFeaturedItemHorizontalListWidgetState
    extends State<_HomeFeaturedItemHorizontalListWidget> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<FeaturedItemProvider>(
        builder: (BuildContext context, FeaturedItemProvider itemProvider,
            Widget child) {
          return AnimatedBuilder(
            animation: widget.animationController,
            child: (itemProvider.itemList.data != null &&
                    itemProvider.itemList.data.isNotEmpty)
                ? Column(
                    children: <Widget>[
                      _MyHeaderWidget(
                        headerName:
                            Utils.getString(context, 'dashboard__feature_item'),
                        viewAllClicked: () {
                          Navigator.pushNamed(
                              context, RoutePaths.filterItemList,
                              arguments: ItemListIntentHolder(
                                  checkPage: '0',
                                  appBarTitle: Utils.getString(
                                      context, 'dashboard__feature_item'),
                                  itemParameterHolder: ItemParameterHolder()
                                      .getFeaturedParameterHolder()));
                        },
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: PsDimens.space16),
                        child: Text(
                          Utils.getString(
                              context, 'dashboard__feature_item_description'),
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                      Container(
                          height: PsDimens.space300,
                          width: MediaQuery.of(context).size.width,
                          child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.only(left: PsDimens.space16),
                              itemCount: itemProvider.itemList.data.length,
                              itemBuilder: (BuildContext context, int index) {
                                if (itemProvider.itemList.status ==
                                    PsStatus.BLOCK_LOADING) {
                                  return Shimmer.fromColors(
                                      baseColor: PsColors.grey,
                                      highlightColor: PsColors.white,
                                      child: Row(children: const <Widget>[
                                        PsFrameUIForLoading(),
                                      ]));
                                } else {
                                  final Item item =
                                      itemProvider.itemList.data[index];
                                  return ItemHorizontalListItem(
                                    coreTagKey:
                                        itemProvider.hashCode.toString() +
                                            item.id, //'feature',
                                    item: itemProvider.itemList.data[index],
                                    onTap: () async {
                                      print(itemProvider.itemList.data[index]
                                          .defaultPhoto.imgPath);
                                      final ItemDetailIntentHolder holder =
                                          ItemDetailIntentHolder(
                                        itemId: item.id,
                                        heroTagImage: '',
                                        heroTagTitle: '',
                                        heroTagOriginalPrice: '',
                                        heroTagUnitPrice: '',
                                      );

                                      final dynamic result =
                                          await Navigator.pushNamed(
                                              context, RoutePaths.itemDetail,
                                              arguments: holder);
                                      if (result == null) {
                                        setState(() {
                                          itemProvider.resetFeatureItemList(
                                              ItemParameterHolder()
                                                  .getFeaturedParameterHolder());
                                        });
                                      }
                                    },
                                  );
                                }
                              }))
                    ],
                  )
                : Container(),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                opacity: widget.animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - widget.animation.value), 0.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeNearMeItemHorizontalListWidget extends StatefulWidget {
  const _HomeNearMeItemHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
    @required this.globalCoordinate,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;
  final geo.Coordinate globalCoordinate;

  @override
  __HomeNearMeItemHorizontalListWidgetState createState() =>
      __HomeNearMeItemHorizontalListWidgetState();
}

class __HomeNearMeItemHorizontalListWidgetState
    extends State<_HomeNearMeItemHorizontalListWidget> {

  ItemRepository itemRepo;
  PsValueHolder psValueHolder;

  @override
  Widget build(BuildContext context) {
    itemRepo = Provider.of<ItemRepository>(context);
    psValueHolder = Provider.of<PsValueHolder>(context);
    return SliverToBoxAdapter(
      child: Consumer<NearMeItemProvider>(
        builder: (BuildContext context, NearMeItemProvider itemProvider,
            Widget child) {
          print('Near Me:${itemProvider.itemList.data.length}');
          return AnimatedBuilder(
            animation: widget.animationController,
            child: (itemProvider.itemList.data != null &&
                    itemProvider.itemList.data.isNotEmpty)
                ? Column(
                    children: <Widget>[
                      _MyHeaderWidget(
                        headerName: 'Near Me',
                        viewAllClicked: () {

                         

                          Navigator.pushNamed(
                              context, RoutePaths.filterItemList,
                              arguments: ItemListIntentHolder(
                                  checkPage: '0',
                                  appBarTitle: 'Near Me',
                                  itemParameterHolder: ItemParameterHolder()
                                      .getNearMeParameterHolder()));
                        },
                      ),
                      Container(),
                      Container(
                          height: PsDimens.space300,
                          width: MediaQuery.of(context).size.width,
                          child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.only(left: PsDimens.space16),
                              itemCount: itemProvider.itemList.data.length,
                              itemBuilder: (BuildContext context, int index) {
                                if (itemProvider.itemList.status ==
                                    PsStatus.BLOCK_LOADING) {
                                  return Shimmer.fromColors(
                                      baseColor: PsColors.grey,
                                      highlightColor: PsColors.white,
                                      child: Row(children: const <Widget>[
                                        PsFrameUIForLoading(),
                                      ]));
                                } else {
                                  final Item item =
                                      itemProvider.itemList.data[index];

                                  ItemDetailProvider itemDetailProvider = ItemDetailProvider(
                                      repo: itemRepo,
                                      psValueHolder: psValueHolder);

                                  final String loginUserId =
                                      Utils.checkUserLoginId(psValueHolder);
                                  ;
                                  print('-----------------${item.id}');
                                  return FutureBuilder<dynamic>(
                                    future: itemDetailProvider.loadItem(
                                        item.id, loginUserId),
                                    builder: (context, snapshot) {
                                      if (itemDetailProvider != null &&
                                          itemDetailProvider.itemDetail !=
                                              null &&
                                          itemDetailProvider.itemDetail.data !=
                                              null) {
                                        return ItemHorizontalListItem(
                                          coreTagKey:
                                              itemProvider.hashCode.toString() +
                                                  item.id, //'feature',
                                          // item: itemProvider.itemList.data[index],
                                          item: itemDetailProvider
                                              .itemDetail.data,
                                          onTap: () async {
                                            // print(itemProvider.itemList.data[index]
                                            //     .defaultPhoto?.imgPath);
                                            final ItemDetailIntentHolder
                                                holder = ItemDetailIntentHolder(
                                              itemId: item.id,
                                              heroTagImage: '',
                                              heroTagTitle: '',
                                              heroTagOriginalPrice: '',
                                              heroTagUnitPrice: '',
                                            );

                                            final dynamic result =
                                                await Navigator.pushNamed(
                                                    context,
                                                    RoutePaths.itemDetail,
                                                    arguments: holder);
                                            if (result == null) {
                                              setState(() {
                                                itemProvider
                                                    .resetNearMeItemList(widget
                                                        .globalCoordinate);
                                              });
                                            }
                                          },
                                        );
                                      } else {
                                        return ItemHorizontalListItem(
                                          coreTagKey:
                                          itemProvider.hashCode.toString() +
                                              item.id, //'feature',
                                          // item: itemProvider.itemList.data[index],
                                          item: item,
                                          onTap: () async {
                                            // print(itemProvider.itemList.data[index]
                                            //     .defaultPhoto?.imgPath);
                                            final ItemDetailIntentHolder
                                            holder = ItemDetailIntentHolder(
                                              itemId: item.id,
                                              heroTagImage: '',
                                              heroTagTitle: '',
                                              heroTagOriginalPrice: '',
                                              heroTagUnitPrice: '',
                                            );

                                            final dynamic result =
                                            await Navigator.pushNamed(
                                                context,
                                                RoutePaths.itemDetail,
                                                arguments: holder);
                                            if (result == null) {
                                              setState(() {
                                                itemProvider
                                                    .resetNearMeItemList(widget
                                                    .globalCoordinate);
                                              });
                                            }
                                          },
                                        );
                                      }
                                    },
                                  );
                                }
                              }))
                    ],
                  )
                : Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: PsDimens.space16),
              child: Text(
                'Black Businesses Not Near me',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyText1,
              ),
            ),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                opacity: widget.animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - widget.animation.value), 0.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeNewCityHorizontalListWidget extends StatefulWidget {
  const _HomeNewCityHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeNewCityHorizontalListWidgetState createState() =>
      __HomeNewCityHorizontalListWidgetState();
}

class __HomeNewCityHorizontalListWidgetState
    extends State<_HomeNewCityHorizontalListWidget> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<CityProvider>(
        builder:
            (BuildContext context, CityProvider cityProvider, Widget child) {
          return AnimatedBuilder(
              animation: widget.animationController,
              child: Column(children: <Widget>[
                _MyHeaderWidget(
                  headerName:
                      Utils.getString(context, 'dashboard__latest_city'),
                  viewAllClicked: () {
                    Navigator.pushNamed(context, RoutePaths.citySearch,
                        arguments: CityIntentHolder(
                          appBarTitle: Utils.getString(
                              context, 'dashboard__latest_city'),
                          cityParameterHolder:
                              CityParameterHolder().getRecentCities(),
                        ));
                  },
                ),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: PsDimens.space16),
                  child: Text(
                    Utils.getString(
                        context, 'dashboard__latest_city_description'),
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
                Container(
                    height: PsDimens.space320,
                    width: MediaQuery.of(context).size.width,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: PsDimens.space16),
                        itemCount: cityProvider.cityList.data.length,
                        itemBuilder: (BuildContext context, int index) {
                          if (cityProvider.cityList.status ==
                              PsStatus.BLOCK_LOADING) {
                            return Shimmer.fromColors(
                                baseColor: PsColors.grey,
                                highlightColor: PsColors.white,
                                child: Row(children: const <Widget>[
                                  PsFrameUIForLoading(),
                                ]));
                          } else {
                            final City city = cityProvider.cityList.data[index];

                            return CityHorizontalListItem(
                              coreTagKey: cityProvider.hashCode.toString() +
                                  city.id, //'latest',
                              city: city,
                              onTap: () async {
                                await cityProvider.replaceCityInfoData(
                                  cityProvider.cityList.data[index].id,
                                  cityProvider.cityList.data[index].name,
                                  cityProvider.cityList.data[index].lat,
                                  cityProvider.cityList.data[index].lng,
                                );
                                Navigator.pushNamed(
                                  context,
                                  RoutePaths.itemHome,
                                  arguments: city,
                                );
                              },
                            );
                          }
                        }))
              ]),
              // : Container(),
              builder: (BuildContext context, Widget child) {
                if (cityProvider.cityList.data != null &&
                    cityProvider.cityList.data.isNotEmpty) {
                  return FadeTransition(
                    opacity: widget.animation,
                    child: Transform(
                      transform: Matrix4.translationValues(
                          0.0, 100 * (1.0 - widget.animation.value), 0.0),
                      child: child,
                    ),
                  );
                } else {
                  return Container();
                }
              });
        },
      ),
    );
  }
}

class _HomeBlogSliderWidget extends StatelessWidget {
  const _HomeBlogSliderWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    // const int count = 5;
    // final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0)
    //     .animate(CurvedAnimation(
    //         parent: animationController,
    //         curve: const Interval((1 / count) * 1, 1.0,
    //             curve: Curves.fastOutSlowIn)));

    return SliverToBoxAdapter(
      child: Consumer<BlogProvider>(builder:
          (BuildContext context, BlogProvider blogProvider, Widget child) {
        return AnimatedBuilder(
            animation: animationController,
            child: (blogProvider.blogList != null &&
                    blogProvider.blogList.data.isNotEmpty)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _MyHeaderWidget(
                        headerName:
                            Utils.getString(context, 'dashboard__blog_item'),
                        viewAllClicked: () {
                          Navigator.pushNamed(
                            context,
                            RoutePaths.blogList,
                          );
                        },
                      ),
                      Container(
                        // decoration: BoxDecoration(
                        //   boxShadow: <BoxShadow>[
                        //     BoxShadow(
                        //         color: PsColors.mainLightShadowColor,
                        //         offset: const Offset(1.1, 1.1),
                        //         blurRadius: PsDimens.space8),
                        //   ],
                        // ),
                        // margin: const EdgeInsets.only(
                        //     top: PsDimens.space8,
                        //     bottom: PsDimens.space20),
                        width: double.infinity,
                        child: BlogSliderView(
                          blogList: blogProvider.blogList.data,
                          onTap: (Blog blog) {
                            Navigator.pushNamed(
                              context,
                              RoutePaths.blogDetail,
                              arguments: blog,
                            );
                          },
                        ),
                      ),
                      // const PsAdMobBannerWidget(),
                    ],
                  )
                : Container(),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                  opacity: animation,
                  child: Transform(
                    transform: Matrix4.translationValues(
                        0.0, 100 * (1.0 - animation.value), 0.0),
                    child: child,
                  ));
            });
      }),
    );
  }
}

class _HomeRecommandedCityHorizontalListWidget extends StatefulWidget {
  const _HomeRecommandedCityHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeRecommandedCityHorizontalListWidgetState createState() =>
      __HomeRecommandedCityHorizontalListWidgetState();
}

class __HomeRecommandedCityHorizontalListWidgetState
    extends State<_HomeRecommandedCityHorizontalListWidget> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<RecommandedCityProvider>(
        builder: (BuildContext context, RecommandedCityProvider provider,
            Widget child) {
          return AnimatedBuilder(
            animation: widget.animationController,
            child: (provider.recommandedCityList.data != null &&
                    provider.recommandedCityList.data.isNotEmpty)
                ? Column(
                    children: <Widget>[
                      Container(
                        color: Utils.isLightMode(context)
                            ? Colors.yellow[50]
                            : Colors.black12,
                        child: Column(
                          children: <Widget>[
                            _MyHeaderWidget(
                              headerName: Utils.getString(
                                  context, 'dashboard__promotion_city'),
                              viewAllClicked: () {
                                Navigator.pushNamed(
                                    context, RoutePaths.citySearch,
                                    arguments: CityIntentHolder(
                                        appBarTitle: Utils.getString(context,
                                            'dashboard__promotion_city'),
                                        cityParameterHolder:
                                            CityParameterHolder()
                                                .getFeaturedCities()));
                              },
                            ),
                            Container(
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.only(left: PsDimens.space16),
                              child: Text(
                                Utils.getString(context,
                                    'dashboard__promotion_city_description'),
                                textAlign: TextAlign.start,
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ),
                            Container(
                                height: PsDimens.space300,
                                color: Utils.isLightMode(context)
                                    ? Colors.yellow[50]
                                    : Colors.black12,
                                width: MediaQuery.of(context).size.width,
                                child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.only(
                                        left: PsDimens.space16),
                                    itemCount: provider
                                        .recommandedCityList.data.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      if (provider.recommandedCityList.status ==
                                          PsStatus.BLOCK_LOADING) {
                                        return Shimmer.fromColors(
                                            baseColor: PsColors.grey,
                                            highlightColor: PsColors.white,
                                            child: Row(children: const <Widget>[
                                              PsFrameUIForLoading(),
                                            ]));
                                      } else {
                                        final City item = provider
                                            .recommandedCityList.data[index];
                                        return CityHorizontalListItem(
                                          coreTagKey:
                                              provider.hashCode.toString() +
                                                  item.id, //'feature',
                                          city: provider
                                              .recommandedCityList.data[index],
                                          onTap: () async {
                                            await provider.replaceCityInfoData(
                                              provider.recommandedCityList
                                                  .data[index].id,
                                              provider.recommandedCityList
                                                  .data[index].name,
                                              provider.recommandedCityList
                                                  .data[index].lat,
                                              provider.recommandedCityList
                                                  .data[index].lng,
                                            );
                                            Navigator.pushNamed(
                                              context,
                                              RoutePaths.itemHome,
                                              arguments: provider
                                                  .recommandedCityList
                                                  .data[index],
                                            );
                                          },
                                        );
                                      }
                                    }))
                          ],
                        ),
                      ),
                      // const PsAdMobBannerWidget(),
                    ],
                  )
                : Container(),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                opacity: widget.animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - widget.animation.value), 0.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeTrendingItemHorizontalListWidget extends StatefulWidget {
  const _HomeTrendingItemHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeTrendingItemHorizontalListWidgetState createState() =>
      __HomeTrendingItemHorizontalListWidgetState();
}

class __HomeTrendingItemHorizontalListWidgetState
    extends State<_HomeTrendingItemHorizontalListWidget> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<TrendingItemProvider>(
        builder: (BuildContext context, TrendingItemProvider itemProvider,
            Widget child) {
          return AnimatedBuilder(
            animation: widget.animationController,
            child: (itemProvider.itemList.data != null &&
                    itemProvider.itemList.data.isNotEmpty)
                ? Column(
                    children: <Widget>[
                      _MyHeaderWidget(
                        headerName: Utils.getString(
                            context, 'dashboard__trending_item'),
                        viewAllClicked: () {
                          Navigator.pushNamed(
                              context, RoutePaths.filterItemList,
                              arguments: ItemListIntentHolder(
                                  checkPage: '0',
                                  appBarTitle: Utils.getString(
                                      context, 'dashboard__trending_item'),
                                  itemParameterHolder: ItemParameterHolder()
                                      .getTrendingParameterHolder()));
                        },
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: PsDimens.space16),
                        child: Text(
                          Utils.getString(
                              context, 'dashboard__trending_item_description'),
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                      Container(
                        height: PsDimens.space320,
                        width: MediaQuery.of(context).size.width,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.only(left: PsDimens.space16),
                            itemCount: itemProvider.itemList.data.length,
                            itemBuilder: (BuildContext context, int index) {
                              if (itemProvider.itemList.status ==
                                  PsStatus.BLOCK_LOADING) {
                                return Shimmer.fromColors(
                                    baseColor: PsColors.grey,
                                    highlightColor: PsColors.white,
                                    child: Row(children: const <Widget>[
                                      PsFrameUIForLoading(),
                                    ]));
                              } else {
                                final Item item =
                                    itemProvider.itemList.data[index];
                                return ItemHorizontalListItem(
                                  coreTagKey: itemProvider.hashCode.toString() +
                                      item.id,
                                  item: itemProvider.itemList.data[index],
                                  onTap: () async {
                                    print(itemProvider.itemList.data[index]
                                        .defaultPhoto.imgPath);
                                    final ItemDetailIntentHolder holder =
                                        ItemDetailIntentHolder(
                                      itemId: item.id,
                                      heroTagImage: '',
                                      heroTagTitle: '',
                                      heroTagOriginalPrice: '',
                                      heroTagUnitPrice: '',
                                    );
                                    final dynamic result =
                                        await Navigator.pushNamed(
                                            context, RoutePaths.itemDetail,
                                            arguments: holder);
                                    if (result == null) {
                                      itemProvider.resetTrendingItemList(
                                          ItemParameterHolder()
                                              .getTrendingParameterHolder());
                                    }
                                  },
                                );
                              }
                            }),
                      )
                    ],
                  )
                : Container(),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                opacity: widget.animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - widget.animation.value), 0.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeOnPromotionHorizontalListWidget extends StatefulWidget {
  const _HomeOnPromotionHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeOnPromotionHorizontalListWidgetState createState() =>
      __HomeOnPromotionHorizontalListWidgetState();
}

class __HomeOnPromotionHorizontalListWidgetState
    extends State<_HomeOnPromotionHorizontalListWidget> {
  bool isConnectedToInternet = false;
  bool isSuccessfullyLoaded = true;

  void checkConnection() {
    Utils.checkInternetConnectivity().then((bool onValue) {
      isConnectedToInternet = onValue;
      if (isConnectedToInternet && PsConfig.showAdMob) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isConnectedToInternet && PsConfig.showAdMob) {
      print('loading ads....');
      checkConnection();
    }
    return SliverToBoxAdapter(child: Consumer<DiscountItemProvider>(builder:
        (BuildContext context, DiscountItemProvider itemProvider,
            Widget child) {
      return AnimatedBuilder(
          animation: widget.animationController,
          child: (itemProvider.itemList.data != null &&
                  itemProvider.itemList.data.isNotEmpty)
              ? Column(children: <Widget>[
                  _MyHeaderWidget(
                    headerName:
                        Utils.getString(context, 'dashboard__promotion_item'),
                    viewAllClicked: () {
                      Navigator.pushNamed(context, RoutePaths.filterItemList,
                          arguments: ItemListIntentHolder(
                              checkPage: '0',
                              appBarTitle: Utils.getString(
                                  context, 'dashboard__promotion_item'),
                              itemParameterHolder: ItemParameterHolder()
                                  .getDiscountParameterHolder()));
                    },
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: PsDimens.space16),
                    child: Text(
                      Utils.getString(
                          context, 'dashboard__promotion_item_description'),
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ),
                  Container(
                      height: PsDimens.space320,
                      width: MediaQuery.of(context).size.width,
                      child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.only(left: PsDimens.space16),
                          itemCount: itemProvider.itemList.data.length,
                          itemBuilder: (BuildContext context, int index) {
                            if (itemProvider.itemList.status ==
                                PsStatus.BLOCK_LOADING) {
                              return Shimmer.fromColors(
                                  baseColor: PsColors.grey,
                                  highlightColor: PsColors.white,
                                  child: Row(children: const <Widget>[
                                    PsFrameUIForLoading(),
                                  ]));
                            } else {
                              final Item item =
                                  itemProvider.itemList.data[index];
                              return ItemHorizontalListItem(
                                coreTagKey:
                                    itemProvider.hashCode.toString() + item.id,
                                item: itemProvider.itemList.data[index],
                                onTap: () async {
                                  print(itemProvider.itemList.data[index]
                                      .defaultPhoto.imgPath);
                                  final ItemDetailIntentHolder holder =
                                      ItemDetailIntentHolder(
                                    itemId: item.id,
                                    heroTagImage: '',
                                    heroTagTitle: '',
                                    heroTagOriginalPrice: '',
                                    heroTagUnitPrice: '',
                                  );
                                  final dynamic result =
                                      await Navigator.pushNamed(
                                          context, RoutePaths.itemDetail,
                                          arguments: holder);
                                  if (result == null) {
                                    itemProvider.resetDiscountItemList(
                                        ItemParameterHolder()
                                            .getDiscountParameterHolder());
                                  }
                                },
                              );
                            }
                          })),
                  const PsAdMobBannerWidget(
                    // admobBannerSize: AdmobBannerSize.MEDIUM_RECTANGLE,
                    admobSize: NativeAdmobType.full,
                  ),
                  // Visibility(
                  //   visible: PsConfig.showAdMob &&
                  //       isSuccessfullyLoaded &&
                  //       isConnectedToInternet,
                  //   child: AdmobBanner(
                  //     adUnitId: Utils.getBannerAdUnitId(),
                  //     adSize: AdmobBannerSize.MEDIUM_RECTANGLE,
                  //     listener: (AdmobAdEvent event,
                  //         Map<String, dynamic> map) {
                  //       print('BannerAd event is $event');
                  //       if (event == AdmobAdEvent.loaded) {
                  //         isSuccessfullyLoaded = true;
                  //       } else {
                  //         isSuccessfullyLoaded = false;
                  //         setState(() {});
                  //       }
                  //     },
                  //   ),
                  // ),
                ])
              : Container(),
          builder: (BuildContext context, Widget child) {
            return FadeTransition(
                opacity: widget.animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - widget.animation.value), 0.0),
                  child: child,
                ));
          });
    }));
  }
}

class _MyHomeHeaderWidget extends StatefulWidget {
  const _MyHomeHeaderWidget(
      {Key key,
      @required this.animationController,
      @required this.animation,
      @required this.userInputItemNameTextEditingController,
      @required this.psValueHolder})
      : super(key: key);

  final TextEditingController userInputItemNameTextEditingController;
  final PsValueHolder psValueHolder;
  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __MyHomeHeaderWidgetState createState() => __MyHomeHeaderWidgetState();
}

class __MyHomeHeaderWidgetState extends State<_MyHomeHeaderWidget> {
  @override
  Widget build(BuildContext context) {
    const Widget _spacingWidget = SizedBox(
      height: PsDimens.space8,
    );
    return SliverToBoxAdapter(
        child: AnimatedBuilder(
            animation: widget.animationController,
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(
                  left: PsDimens.space12, right: PsDimens.space12),
              //top: PsDimens.space64),
              // decoration: BoxDecoration(
              //   borderRadius: BorderRadius.circular(PsDimens.space12),
              //   // color:  Colors.white54
              //   color: Utils.isLightMode(context)
              //       ? Colors.white54
              //       : Colors.black54,
              // ),
              child: Column(
                children: <Widget>[
                  /*_spacingWidget,
                  // _spacingWidget,
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        Utils.getString(context, 'app_name'),
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(fontSize: PsDimens.space32),
                      ),
                      _spacingWidget,
                      Container(
                        margin: const EdgeInsets.only(
                            left: PsDimens.space20,
                            right: PsDimens.space20,
                            bottom: PsDimens.space32),
                    //    child: Text(
                      //    Utils.getString(
                        //      context, 'dashboard__app_description'),
                          //textAlign: TextAlign.right,
                         // style: Theme.of(context)
                           //   .textTheme
                             // .subtitle1
                              //.copyWith(color: PsColors.mainColor),
                        ),
                      ),
                    ],
                  ),

                  _spacingWidget, */
                  PsTextFieldWidgetWithIcon(
                    hintText:
                        Utils.getString(context, 'dashboard__search_keyword'),
                    textEditingController:
                        widget.userInputItemNameTextEditingController,
                    psValueHolder: widget.psValueHolder,
                  ),
                  _spacingWidget
                ],
              ),
            ),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                  opacity: widget.animation,
                  child: Transform(
                    transform: Matrix4.translationValues(
                        0.0, 100 * (1.0 - widget.animation.value), 0.0),
                    child: child,
                  ));
            }));
  }
}

class _HomePopularCityHorizontalListWidget extends StatelessWidget {
  const _HomePopularCityHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<PopularCityProvider>(
        builder: (BuildContext context, PopularCityProvider popularCityProvider,
            Widget child) {
          return AnimatedBuilder(
            animation: animationController,
            child: (popularCityProvider.popularCityList.data != null &&
                    popularCityProvider.popularCityList.data.isNotEmpty)
                ? Column(children: <Widget>[
                    _MyHeaderWidget(
                      headerName:
                          Utils.getString(context, 'dashboard__popular_city'),
                      viewAllClicked: () {
                        Navigator.pushNamed(context, RoutePaths.citySearch,
                            arguments: CityIntentHolder(
                                appBarTitle: Utils.getString(
                                    context, 'dashboard__popular_city'),
                                cityParameterHolder:
                                    CityParameterHolder().getPopularCities()));
                      },
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: PsDimens.space16),
                      child: Text(
                        Utils.getString(
                            context, 'dashboard__popular_city_description'),
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(PsDimens.space16),
                      child: Container(
                          height: 500,
                          width: MediaQuery.of(context).size.width,
                          child: CustomScrollView(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            slivers: <Widget>[
                              SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 400,
                                          childAspectRatio: 0.9),
                                  delegate: SliverChildBuilderDelegate(
                                    (BuildContext context, int index) {
                                      if (popularCityProvider
                                              .popularCityList.status ==
                                          PsStatus.BLOCK_LOADING) {
                                        return Shimmer.fromColors(
                                            baseColor: PsColors.grey,
                                            highlightColor: PsColors.white,
                                            child: Row(children: const <Widget>[
                                              PsFrameUIForLoading(),
                                            ]));
                                      } else {
                                        return PopularCityHorizontalListItem(
                                          city: popularCityProvider
                                              .popularCityList.data[index],
                                          onTap: () async {
                                            await popularCityProvider
                                                .replaceCityInfoData(
                                              popularCityProvider
                                                  .popularCityList
                                                  .data[index]
                                                  .id,
                                              popularCityProvider
                                                  .popularCityList
                                                  .data[index]
                                                  .name,
                                              popularCityProvider
                                                  .popularCityList
                                                  .data[index]
                                                  .lat,
                                              popularCityProvider
                                                  .popularCityList
                                                  .data[index]
                                                  .lng,
                                            );
                                            Navigator.pushNamed(
                                              context,
                                              RoutePaths.itemHome,
                                              arguments: popularCityProvider
                                                  .popularCityList.data[index],
                                            );
                                          },
                                        );
                                      }
                                    },
                                    childCount: popularCityProvider
                                        .popularCityList.data.length,
                                  ))
                            ],
                          )),
                    )
                  ])
                : Container(),
            builder: (BuildContext context, Widget child) {
              return FadeTransition(
                opacity: animation,
                child: Transform(
                  transform: Matrix4.translationValues(
                      0.0, 100 * (1.0 - animation.value), 0.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeNewPlaceHorizontalListWidget extends StatefulWidget {
  const _HomeNewPlaceHorizontalListWidget({
    Key key,
    @required this.animationController,
    @required this.animation,
  }) : super(key: key);

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  __HomeNewPlaceHorizontalListWidgetState createState() =>
      __HomeNewPlaceHorizontalListWidgetState();
}

class __HomeNewPlaceHorizontalListWidgetState
    extends State<_HomeNewPlaceHorizontalListWidget> {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<SearchItemProvider>(
        builder: (BuildContext context, SearchItemProvider itemProvider,
            Widget child) {
          return AnimatedBuilder(
              animation: widget.animationController,
              child: Column(children: <Widget>[
                _MyHeaderWidget(
                  headerName:
                      Utils.getString(context, 'dashboard__popular_item'),
                  viewAllClicked: () {
                    Navigator.pushNamed(context, RoutePaths.filterItemList,
                        arguments: ItemListIntentHolder(
                          checkPage: '0',
                          appBarTitle: Utils.getString(
                              context, 'dashboard__popular_item'),
                          itemParameterHolder:
                              ItemParameterHolder().getLatestParameterHolder(),
                        ));
                  },
                ),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: PsDimens.space16),
                  child: Text(
                    Utils.getString(
                        context, 'dashboard__popular_item_description'),
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
                Container(
                    height: PsDimens.space320,
                    width: MediaQuery.of(context).size.width,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: PsDimens.space16),
                        itemCount: itemProvider.itemList.data.length,
                        itemBuilder: (BuildContext context, int index) {
                          if (itemProvider.itemList.status ==
                              PsStatus.BLOCK_LOADING) {
                            return Shimmer.fromColors(
                                baseColor: PsColors.grey,
                                highlightColor: PsColors.white,
                                child: Row(children: const <Widget>[
                                  PsFrameUIForLoading(),
                                ]));
                          } else {
                            final Item item = itemProvider.itemList.data[index];

                            return ItemHorizontalListItem(
                              coreTagKey: itemProvider.hashCode.toString() +
                                  item.id, //'latest',
                              item: item,
                              onTap: () async {
                                print(item.defaultPhoto.imgPath);

                                final ItemDetailIntentHolder holder =
                                    ItemDetailIntentHolder(
                                  itemId: item.id,
                                  heroTagImage: '',
                                  heroTagTitle: '',
                                  heroTagOriginalPrice: '',
                                  heroTagUnitPrice: '',
                                );

                                final dynamic result =
                                    await Navigator.pushNamed(
                                        context, RoutePaths.itemDetail,
                                        arguments: holder);
                                if (result == null) {
                                  setState(() {
                                    itemProvider.resetLatestItemList(
                                        ItemParameterHolder()
                                            .getLatestParameterHolder());
                                  });
                                }
                              },
                            );
                          }
                        }))
              ]),
              // : Container(),
              builder: (BuildContext context, Widget child) {
                if (itemProvider.itemList.data != null &&
                    itemProvider.itemList.data.isNotEmpty) {
                  return FadeTransition(
                    opacity: widget.animation,
                    child: Transform(
                      transform: Matrix4.translationValues(
                          0.0, 100 * (1.0 - widget.animation.value), 0.0),
                      child: child,
                    ),
                  );
                } else {
                  return Container();
                }
              });
        },
      ),
    );
  }
}

class _MyHeaderWidget extends StatefulWidget {
  const _MyHeaderWidget({
    Key key,
    @required this.headerName,
    this.itemCollectionHeader,
    @required this.viewAllClicked,
  }) : super(key: key);

  final String headerName;
  final Function viewAllClicked;
  final ItemCollectionHeader itemCollectionHeader;

  @override
  __MyHeaderWidgetState createState() => __MyHeaderWidgetState();
}

class __MyHeaderWidgetState extends State<_MyHeaderWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.viewAllClicked();
      },
      child: Padding(
        padding: const EdgeInsets.only(
            top: PsDimens.space20,
            left: PsDimens.space16,
            right: PsDimens.space16,
            bottom: PsDimens.space10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(widget.headerName,
                  style: Theme.of(context).textTheme.headline6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: PsColors.textPrimaryDarkColor)),
            ),
            Text(
              Utils.getString(context, 'dashboard__view_all'),
              textAlign: TextAlign.start,
              style: Theme.of(context)
                  .textTheme
                  .caption
                  .copyWith(color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
