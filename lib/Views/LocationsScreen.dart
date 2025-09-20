import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vpn_app/Views/Constant.dart';
import 'package:vpn_app/Controller/Api/apis.dart';
import 'package:vpn_app/Models/vpn_server.dart' as models;
import 'package:vpn_app/Providers/homeProvider.dart';


class LocationsScreen extends StatefulWidget {
  final String? selected;
  const LocationsScreen({super.key, this.selected});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  // Static cache for last successful server list
  static List<models.VpnServer> _cachedServers = [];
  static Map<String, List<models.VpnServer>> _cachedGrouped = {};
  static List<String> _cachedCountryOrder = [];
  final TextEditingController _searchCtrl = TextEditingController();
  Map<String, List<models.VpnServer>> _grouped = {};
  List<String> _countryOrder = [];
  Set<String> _expanded = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchServers();
    _searchCtrl.addListener(_applyFilter);
  }


  Future<void> _fetchServers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    List<models.VpnServer> servers = [];
    String source = '';
    try {
      debugPrint('Trying Technosofts...');
  servers = await ApiService.fetchTechnosoftsServers(context);
      if (servers.isNotEmpty) source = 'Technosofts';
  // No ping field in new model, so skip sorting by ping
      if (servers.isNotEmpty) {
        final Map<String, List<models.VpnServer>> grouped = {};
        for (final s in servers) {
          grouped.putIfAbsent(s.country, () => []).add(s);
        }
        // Cache the successful result
        _cachedServers = servers;
        _cachedGrouped = grouped;
        _cachedCountryOrder = grouped.keys.toList();
        setState(() {
          _grouped = grouped;
          _countryOrder = grouped.keys.toList();
          _loading = false;
        });
        debugPrint('Fetched ${servers.length} servers from $source, ${grouped.length} countries');
      } else {
        // If cache exists, use it
        if (_cachedServers.isNotEmpty) {
          setState(() {
            _grouped = _cachedGrouped;
            _countryOrder = _cachedCountryOrder;
            _loading = false;
            _error = null;
          });
          debugPrint('Fetch failed, showing cached servers (${_cachedServers.length})');
        } else {
          setState(() {
            _grouped = {};
            _countryOrder = [];
            _loading = false;
            _error = 'No servers available right now.';
          });
          debugPrint('All sources returned 0 servers and no cache.');
        }
      }
    } catch (e) {
      // If cache exists, use it
      if (_cachedServers.isNotEmpty) {
        setState(() {
          _grouped = _cachedGrouped;
          _countryOrder = _cachedCountryOrder;
          _loading = false;
          _error = null;
        });
        debugPrint('Fetch error, showing cached servers (${_cachedServers.length})');
      } else {
        setState(() {
          _error = 'Unable to load servers. Please check your internet and try again.';
          _loading = false;
        });
        debugPrint('Server fetch error: $e and no cache.');
      }
    }
  }


  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _countryOrder = _grouped.keys.toList();
      });
    } else {
      setState(() {
        _countryOrder = _grouped.keys.where((k) => k.toLowerCase().contains(q)).toList();
      });
    }
  }



  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primarycolor,
      appBar: AppBar(
        backgroundColor: primarycolor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Select Server', style: boldStyle.copyWith(fontSize: 18)),
        actions: [
          if (widget.selected != null)
            Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Center(
                child: Text(
                  'Current: ${widget.selected!}',
                  style: mediumStyle.copyWith(fontSize: 11, color: Colors.white70),
                ),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardcolor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search location',
                        hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                        border: InputBorder.none,
                      ),
                      cursorColor: Colors.white54,
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilter();
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: mediumStyle.copyWith(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchServers, child: const Text('Retry')),
                          ],
                        ),
                      )
                        : _countryOrder.isEmpty
                            ? Center(child: Text('No servers found', style: mediumStyle.copyWith(color: Colors.white54)))
                            : ListView.separated(
                                itemCount: _countryOrder.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.06),
                                  indent: 72,
                                ),
                                itemBuilder: (context, index) {
                                  final country = _countryOrder[index];
                                  final servers = _grouped[country]!;
                                  final best = servers.first;
                                  final isExpanded = _expanded.contains(country);
                                  final bool isSelected = best.country == widget.selected;
                                  return Column(
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          final hp = context.read<HomeProvider>();
                                          hp.setServer(best);
                                          if (mounted) {
                                            Navigator.pop(context, {
                                              'name': best.country,
                                              'code': best.countryCode.toLowerCase(),
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                                                  image: DecorationImage(
                                                    image: AssetImage('assets/flags/${best.countryCode.toLowerCase()}.png'),
                                                    fit: BoxFit.cover,
                                                    onError: (e, st) {},
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(best.country, style: boldStyle.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.network_check, size: 14, color: Colors.white54),
                                                        const SizedBox(width: 4),
                                                        // No ping field in new model, so remove this line
                                                        const SizedBox(width: 12),
                                                        Icon(Icons.speed, size: 14, color: Colors.white54),
                                                        const SizedBox(width: 4),
                                                        // No speed field in new model, so remove this line
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white54),
                                                onPressed: () {
                                                  setState(() {
                                                    if (isExpanded) {
                                                      _expanded.remove(country);
                                                    } else {
                                                      _expanded.add(country);
                                                    }
                                                  });
                                                },
                                              ),
                                              if (isSelected)
                                                Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
                                              else
                                                Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isExpanded)
                                        ...servers.map((s) => Padding(
                                          padding: const EdgeInsets.only(left: 32.0),
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(s.ipAddress, style: mediumStyle.copyWith(color: Colors.white70, fontSize: 13)),
                                            // onTap intentionally removed so IP addresses are not clickable
                                          ),
                                        )),
                                    ],
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}

