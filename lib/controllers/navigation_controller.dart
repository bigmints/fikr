import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxInt index = 0.obs;
  final RxBool isSearching = false.obs;

  void setIndex(int value) => index.value = value;

  void toggleSearch() {
    isSearching.value = !isSearching.value;
  }

  void closeSearch() {
    isSearching.value = false;
  }
}
