import 'package:flutter/foundation.dart';

class ActivityTracker extends ChangeNotifier {
  bool _isToppingUp = false;
  bool _isShowingAnyDialog = false;
  bool _isUploading = false;

  // getters
  bool get isToppingUp => _isToppingUp;

  bool get isSyncAllowed {
    return !isToppingUp;
  }

  bool get isMultiSelectEnabled {
    return !_isShowingAnyDialog;
  }

  bool get isUploading => _isUploading;

  // setters
  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void setToppingUp(bool value) {
    _isToppingUp = value;
  }

  void setShowingAnyDialog(bool value) {
    _isShowingAnyDialog = value;
    notifyListeners();
  }
}
