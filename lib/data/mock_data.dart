import 'package:webdlrprtl01/models/product_journey.dart';
import 'package:webdlrprtl01/models/user_profile.dart';

const List<UserProfile> mockUsers = [
  UserProfile(
    email: 'dealer.admin@gmail.com',
    nik: '3201012001010001',
    role: 'Dealer Distribution Admin',
    code: 'dlr.DDD-dist-adm.BBB',
    loa: 'LoA1',
    name: 'Dealer Admin',
  ),
  UserProfile(
    email: 'dealer.manager@gmail.com',
    nik: '3201012001010002',
    role: 'Dealer Distribution Manager',
    code: 'dlr.DDD-dist-mgr.CCC',
    loa: 'LoA3',
    name: 'Dealer Manager',
  ),
  UserProfile(
    email: 'warehouse.admin@gmail.com',
    nik: 'q',
    role: 'Modena Warehouse Distribution Admin',
    code: 'whs-dist-adm.MMM',
    loa: 'LoA2',
    name: 'Warehouse Admin',
  ),
  UserProfile(
    email: 'logistics.driver@gmail.com',
    nik: '3201012001010005',
    role: 'Third Party Logistics Driver',
    code: 'log.LLL-drvr.KKK',
    loa: 'LoA2',
    name: 'Logistics Driver',
  ),
];

const List<ProductJourneyStep> mockJourney = [
  ProductJourneyStep(
    id: 'P-001',
    state: 'Allocated',
    actor: 'dlr.DDD-dist-adm.BBB',
    initBy: 'dealer distribution admin',
    loa: 'LoA1',
    timestamp: DateTime.utc(2026, 8, 14, 9, 0),
  ),
  ProductJourneyStep(
    id: 'P-001',
    state: 'Ordered',
    actor: 'dlr.DDD-dist-mgr.CCC',
    initBy: 'dealer distribution admin',
    loa: 'LoA3',
    timestamp: DateTime.utc(2026, 8, 14, 9, 10),
  ),
  ProductJourneyStep(
    id: 'P-001',
    state: 'Confirmed',
    actor: 'whs-dist-adm.MMM',
    initBy: 'modena warehouse distribution admin',
    loa: 'LoA2',
    timestamp: DateTime.utc(2026, 8, 14, 9, 20),
  ),
];
