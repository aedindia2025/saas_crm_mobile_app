import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_helpers/api_urls.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationState();
}

class _NotificationState extends State<NotificationPage> {
  bool isLoading = true;
  bool unreadOnly = false;

  String token = '';

  List<Map<String, dynamic>> notifications = [];
  int unreadCount = 0;

  String get apiBase => "${ApiUrls.baseUrl}/api/v1";

  Map<String, String> get headers => {
    "Authorization": "Bearer $token",
    "Accept": "application/json",
    "Content-Type": "application/json",
    "X-Tenant-Slug": "ascent",
  };

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      setState(() => isLoading = false);
      showError("Token not found");
      return;
    }

    await loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => isLoading = true);

    try {
      final url = unreadOnly
          ? "$apiBase/notifications?unread_only=true"
          : "$apiBase/notifications";

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          notifications = List<Map<String, dynamic>>.from(
            (data['items'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          unreadCount = data['unread_count'] ?? 0;
        });
      } else {
        showError(response.body);
      }
    } catch (e) {
      showError("Failed to load notifications");
    }

    setState(() => isLoading = false);
  }

  Future<void> markRead(int id) async {
    final oldList = List<Map<String, dynamic>>.from(notifications);

    setState(() {
      notifications = notifications.map((n) {
        if (n['id'] == id) {
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();

      if (unreadOnly) {
        notifications.removeWhere((n) => n['id'] == id);
      }

      unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
    });

    try {
      final response = await http
          .put(
        Uri.parse("$apiBase/notifications/$id/read"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => unreadCount = data['unread_count'] ?? unreadCount);
      } else {
        setState(() => notifications = oldList);
        showError(response.body);
      }
    } catch (e) {
      setState(() => notifications = oldList);
      showError("Failed to mark as read");
    }
  }

  Future<void> markAllRead() async {
    final oldList = List<Map<String, dynamic>>.from(notifications);

    setState(() {
      notifications = notifications.map((n) {
        return {...n, 'is_read': true};
      }).toList();

      if (unreadOnly) notifications.clear();

      unreadCount = 0;
    });

    try {
      final response = await http
          .put(
        Uri.parse("$apiBase/notifications/mark-all-read"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        showSuccess("All marked as read");
      } else {
        setState(() => notifications = oldList);
        showError(response.body);
      }
    } catch (e) {
      setState(() => notifications = oldList);
      showError("Failed to mark all as read");
    }
  }

  Future<void> deleteNotification(int id) async {
    final oldList = List<Map<String, dynamic>>.from(notifications);
    final item = notifications.firstWhere(
          (e) => e['id'] == id,
      orElse: () => {},
    );
    final wasUnread = item['is_read'] == false;

    setState(() {
      notifications.removeWhere((n) => n['id'] == id);
      if (wasUnread) unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
    });

    try {
      final response = await http
          .delete(
        Uri.parse("$apiBase/notifications/$id"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => unreadCount = data['unread_count'] ?? unreadCount);
      } else {
        setState(() => notifications = oldList);
        showError(response.body);
      }
    } catch (e) {
      setState(() => notifications = oldList);
      showError("Failed to delete notification");
    }
  }

  int get approvedCount {
    return notifications.where((n) {
      return n['action']?.toString().contains('approved') == true;
    }).length;
  }

  int get rejectedCount {
    return notifications.where((n) {
      return n['action']?.toString().contains('rejected') == true;
    }).length;
  }

  String timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';

    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;

    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";

    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  Map<String, dynamic> meta(String action) {
    if (action.contains('approved') || action.contains('conversion_approved')) {
      return {
        "icon": Icons.check_circle,
        "color": const Color(0xff16A34A),
        "bg": const Color(0xffDCFCE7),
        "tag": "Approved",
      };
    }

    if (action.contains('rejected') || action.contains('conversion_rejected')) {
      return {
        "icon": Icons.cancel,
        "color": const Color(0xffDC2626),
        "bg": const Color(0xffFEE2E2),
        "tag": "Rejected",
      };
    }

    if (action.contains('request') ||
        action.contains('approval') ||
        action.contains('pending')) {
      return {
        "icon": Icons.access_time,
        "color": const Color(0xffD97706),
        "bg": const Color(0xffFEF3C7),
        "tag": "Pending",
      };
    }

    if (action.contains('warn') || action.contains('alert')) {
      return {
        "icon": Icons.warning_amber,
        "color": const Color(0xffEA580C),
        "bg": const Color(0xffFFEDD5),
        "tag": "Alert",
      };
    }

    return {
      "icon": Icons.info,
      "color": const Color(0xff2563EB),
      "bg": const Color(0xffDBEAFE),
      "tag": "Info",
    };
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xff94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xff0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget notificationCard(Map<String, dynamic> n) {
    final action = n['action']?.toString() ?? '';
    final m = meta(action);
    final isRead = n['is_read'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? const Color(0xffE2E8F0) : const Color(0xffBFDBFE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: m['bg'],
              child: Icon(
                m['icon'],
                color: m['color'],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        n['title']?.toString() ?? '-',
                        style: TextStyle(
                          color: isRead
                              ? const Color(0xff64748B)
                              : const Color(0xff0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      tag(m['tag'], m['color']),
                      if (n['module'] != null)
                        tag(
                          n['module'].toString().toUpperCase(),
                          const Color(0xff64748B),
                        ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  Text(
                    n['message']?.toString() ?? '',
                    style: TextStyle(
                      color: isRead
                          ? const Color(0xff94A3B8)
                          : const Color(0xff475569),
                      height: 1.35,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Text(
                        timeAgo(n['created_at']?.toString()),
                        style: const TextStyle(
                          color: Color(0xff94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!isRead)
                        IconButton(
                          tooltip: "Mark as read",
                          onPressed: () => markRead(n['id']),
                          icon: const Icon(
                            Icons.check,
                            color: Color(0xff16A34A),
                            size: 20,
                          ),
                        ),
                      IconButton(
                        tooltip: "Delete",
                        onPressed: () => deleteNotification(n['id']),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xffDC2626),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: m['color'],
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget filterBar() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          filterButton("All", false),
          filterButton("Unread${unreadCount > 0 ? ' ($unreadCount)' : ''}", true),
        ],
      ),
    );
  }

  Widget filterButton(String text, bool value) {
    final selected = unreadOnly == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => unreadOnly = value);
          loadNotifications();
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 5,
              )
            ]
                : [],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xff0F172A) : const Color(0xff64748B),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget bodyContent() {
    if (isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 105,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      );
    }

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadNotifications,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xffF1F5F9),
              child: Icon(
                unreadOnly ? Icons.notifications_off : Icons.notifications_none,
                color: const Color(0xffCBD5E1),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                unreadOnly ? "No unread notifications" : "No notifications yet",
                style: const TextStyle(
                  color: Color(0xff334155),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                unreadOnly
                    ? "You're all caught up!"
                    : "Notifications will appear here",
                style: const TextStyle(color: Color(0xff94A3B8)),
              ),
            ),
            if (unreadOnly)
              TextButton(
                onPressed: () {
                  setState(() => unreadOnly = false);
                  loadNotifications();
                },
                child: const Text("View all notifications"),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: notifications.map(notificationCard).toList(),
      ),
    );
  }

  void showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Notifications",
              style: TextStyle(
                color: Color(0xff0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "All system alerts and approval updates",
              style: TextStyle(
                color: Color(0xff64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loadNotifications,
            icon: const Icon(Icons.refresh, color: Color(0xff64748B)),
          ),
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: markAllRead,
              icon: const Icon(Icons.done_all, size: 17),
              label: const Text("Read all"),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    statCard(
                      title: "Total",
                      value: notifications.length.toString(),
                      icon: Icons.notifications,
                      color: const Color(0xff2563EB),
                    ),
                    const SizedBox(width: 10),
                    statCard(
                      title: "Unread",
                      value: unreadCount.toString(),
                      icon: Icons.access_time,
                      color: const Color(0xffD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    statCard(
                      title: "Approved",
                      value: approvedCount.toString(),
                      icon: Icons.check_circle,
                      color: const Color(0xff16A34A),
                    ),
                    const SizedBox(width: 10),
                    statCard(
                      title: "Rejected",
                      value: rejectedCount.toString(),
                      icon: Icons.cancel,
                      color: const Color(0xffDC2626),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: filterBar()),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: loadNotifications,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xffE2E8F0)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: bodyContent()),
        ],
      ),
    );
  }
}