import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../utils/notification_overlay.dart';
import '../router/app_router.dart';
import 'user_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final UserProvider _userProvider;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  RealtimeChannel? _channel;
  StreamSubscription? _userSubscription;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider(this._userProvider) {
    _init();
  }

  void _init() {
    // Check initial state
    if (_userProvider.isLoggedIn) {
      _loadNotifications();
      _subscribeToNotifications();
    }

    // Listen to UserProvider changes
    _userProvider.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    if (_userProvider.isLoggedIn) {
      _loadNotifications();
      _subscribeToNotifications();
    } else {
      _clearData();
    }
  }

  Future<void> _loadNotifications() async {
    if (_userProvider.user == null) return;
    
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _userProvider.user!.id;
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = (data as List).map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToNotifications() {
    if (_userProvider.user == null) return;
    
    _channel?.unsubscribe();
    final userId = _userProvider.user!.id;

    _channel = _supabase.channel('public:notifications:user_$userId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord != null) {
          final n = NotificationModel.fromJson(newRecord);
          // Insert at the top
          _notifications.insert(0, n);
          if (!n.isRead) {
            _showOverlay(n);
          }
          notifyListeners();
        }
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord != null) {
          final updated = NotificationModel.fromJson(newRecord);
          final index = _notifications.indexWhere((old) => old.id == updated.id);
          if (index != -1) {
            _notifications[index] = updated;
            notifyListeners();
          }
        }
      },
    ).subscribe();
  }

  void _showOverlay(NotificationModel n) {
    try {
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay != null) {
        NotificationOverlay.show(overlay, title: n.title, message: n.message);
      }
    } catch (e) {
      debugPrint('Error showing overlay: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final original = _notifications[index];
    _notifications[index] = original.copyWith(isRead: true);
    notifyListeners();

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      _notifications[index] = original;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = _notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();

    try {
      if (_userProvider.user == null) return;
      final userId = _userProvider.user!.id;
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  void _clearData() {
    _channel?.unsubscribe();
    _channel = null;
    _notifications = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _userSubscription?.cancel();
    super.dispose();
  }
}
