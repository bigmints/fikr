import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class TestController extends GetxController {}

void main() {
  Get.put(TestController());
  debugPrint(Get.isRegistered<TestController>().toString());
}
