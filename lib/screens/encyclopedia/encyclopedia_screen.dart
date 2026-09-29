import 'package:flutter/material.dart';

import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';

class EncyclopediaScreen extends StatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  State<EncyclopediaScreen> createState() =>
      _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _search = '';
  String? _expandedWarning;

  // ============================================================
  // WARNING LIGHTS
  // ============================================================

  static const warnings = <WarningItem>[
    WarningItem(
      'Check Engine',
      'Engine control system detected an issue.',
      Icons.engineering_outlined,
      'Requires attention',
      'The engine control system has detected an abnormal condition.',
      'If the light remains on, arrange an inspection. If it flashes or the vehicle behaves abnormally, reduce driving and seek assistance.',
    ),
    WarningItem(
      'Oil Pressure',
      'Possible low engine oil pressure.',
      Icons.oil_barrel_outlined,
      'High priority',
      'The engine may not be receiving adequate oil pressure for lubrication.',
      'Stop safely and avoid continuing to drive until the cause has been checked.',
    ),
    WarningItem(
      'Battery / Charging',
      'Charging system may have a problem.',
      Icons.battery_alert_outlined,
      'Requires attention',
      'The battery may not be charging normally.',
      'Reduce unnecessary electrical loads and arrange an inspection.',
    ),
    WarningItem(
      'Brake Warning',
      'Brake system needs attention.',
      Icons.warning_amber_rounded,
      'High priority',
      'The warning can indicate a brake-system or brake-fluid problem.',
      'If braking feels abnormal, stop driving and seek assistance.',
    ),
    WarningItem(
      'ABS',
      'Anti-lock braking system may be unavailable.',
      Icons.car_crash_outlined,
      'Requires attention',
      'The anti-lock braking system may not be operating normally.',
      'Drive cautiously and arrange an inspection.',
    ),
    WarningItem(
      'Engine Temperature',
      'Engine temperature may be too high.',
      Icons.device_thermostat_outlined,
      'High priority',
      'The engine or cooling system may be overheating.',
      'Stop safely and allow the engine to cool. Do not continue if the temperature remains high.',
    ),
    WarningItem(
      'Tyre Pressure',
      'One or more tyres may be under-inflated.',
      Icons.tire_repair_outlined,
      'Check soon',
      'The tyre-pressure system has detected pressure outside its expected range.',
      'Check all tyre pressures and inspect for visible damage or leaks.',
    ),
    WarningItem(
      'Airbag',
      'Supplemental restraint system needs attention.',
      Icons.airline_seat_recline_normal_outlined,
      'Requires attention',
      'A fault may exist in the airbag or restraint system.',
      'Arrange a professional inspection if the warning remains.',
    ),
    WarningItem(
      'Traction Control',
      'Traction-control system may be limited.',
      Icons.tonality_outlined,
      'Check soon',
      'Traction control helps reduce wheel spin during acceleration.',
      'Drive carefully on slippery roads and have the system checked.',
    ),
    WarningItem(
      'ESC',
      'Stability control may be unavailable.',
      Icons.control_camera_outlined,
      'Requires attention',
      'Electronic Stability Control helps maintain vehicle stability.',
      'Drive carefully and arrange an inspection if the warning remains.',
    ),
    WarningItem(
      'Power Steering',
      'Steering assistance may be reduced.',
      Icons.directions_car_filled_outlined,
      'High priority',
      'A problem may exist with the steering-assistance system.',
      'Reduce speed and seek assistance if steering becomes unusually heavy.',
    ),
    WarningItem(
      'Transmission',
      'Transmission system needs attention.',
      Icons.settings_outlined,
      'Requires attention',
      'The transmission may have detected abnormal operation.',
      'Avoid aggressive driving and arrange an inspection.',
    ),
  ];

  // ============================================================
  // SYSTEMS
  // ============================================================

  static const systems = <CategoryItem>[
    CategoryItem(
      'Engine',
      Icons.settings_rounded,
      6,
      [
        'How the engine works',
        'Engine oil',
        'Air intake',
        'Spark plugs',
        'Belts & timing',
        'Common engine problems',
      ],
    ),
    CategoryItem(
      'Braking',
      Icons.stop_circle_outlined,
      5,
      [
        'Brake pads',
        'Brake discs & drums',
        'Brake fluid',
        'ABS',
        'Brake warning signs',
      ],
    ),
    CategoryItem(
      'Wheels & Tyres',
      Icons.tire_repair_outlined,
      5,
      [
        'Tyre pressure',
        'Tyre tread',
        'Wheel alignment',
        'Wheel balancing',
        'Suspension basics',
      ],
    ),
    CategoryItem(
      'Electrical',
      Icons.bolt_rounded,
      4,
      [
        'Battery',
        'Alternator',
        'Starter motor',
        'Vehicle electronics',
      ],
    ),
    CategoryItem(
      'Cooling & Fluids',
      Icons.device_thermostat_outlined,
      5,
      [
        'Engine coolant',
        'Radiator',
        'Transmission fluid',
        'Brake fluid',
        'Fluid warning signs',
      ],
    ),
    CategoryItem(
      'Powertrain',
      Icons.settings_input_component_outlined,
      4,
      [
        'Transmission',
        'Automatic transmission',
        'CVT',
        'DCT',
      ],
    ),
    CategoryItem(
      'Climate & Comfort',
      Icons.ac_unit_outlined,
      3,
      [
        'Air conditioning',
        'Cabin filter',
        'Blower system',
      ],
    ),
    CategoryItem(
      'Maintenance',
      Icons.build_outlined,
      6,
      [
        'Service intervals',
        'Oil changes',
        'Fluid checks',
        'Wear items',
        'Inspection basics',
        'Maintenance records',
      ],
    ),
  ];

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<WarningItem> get filteredWarnings {
    if (_search.trim().isEmpty) return warnings;

    final q = _search.toLowerCase();

    return warnings.where((w) {
      return w.title.toLowerCase().contains(q) ||
          w.description.toLowerCase().contains(q);
    }).toList();
  }

  List<CategoryItem> get filteredSystems {
    if (_search.trim().isEmpty) return systems;

    final q = _search.toLowerCase();

    return systems.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.topics.any(
            (topic) => topic.toLowerCase().contains(q),
          );
    }).toList();
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final searching = _search.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: DLogColors.black,
      body: DLogBackground(
        child: SafeArea(
          child: CustomScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _header(),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  24,
                  18,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _searchBar(),
                ),
              ),

              if (searching)
                ..._searchResults()
              else
                ..._normalContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF101619),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF283136),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: DLogColors.white,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 14),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DLOG',
                style: TextStyle(
                  color: DLogColors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'ENCYCLOPEDIA',
                maxLines: 1,
                style: TextStyle(
                  color: DLogColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Everything you need to understand your car.',
                style: TextStyle(
                  color: DLogColors.grey,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1215),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF283136),
            ),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: DLogColors.white,
            size: 23,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1316),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF283136),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _search = value);
        },
        style: const TextStyle(
          color: DLogColors.white,
          fontSize: 14,
        ),
        cursorColor: DLogColors.burgundyBright,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: DLogColors.grey,
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: DLogColors.grey,
                  ),
                )
              : null,
          hintText:
              'Search components, warnings or systems...',
          hintStyle: const TextStyle(
            color: DLogColors.grey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NORMAL CONTENT
  // ============================================================

  List<Widget> _normalContent() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          28,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _popular(),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          28,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _sectionTitle(
            'DASHBOARD WARNING LIGHTS',
            'Know what your car is telling you.',
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _warningSection(),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          30,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _sectionTitle(
            'EXPLORE YOUR VEHICLE',
            'Understand the systems that keep your car moving.',
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _systemGrid(
            systems.take(6).toList(),
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          30,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _sectionTitle(
            'MORE TO EXPLORE',
            'Useful systems every driver should know.',
          ),
        ),
      ),

      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          32,
        ),
        sliver: SliverToBoxAdapter(
          child: _secondarySystems(),
        ),
      ),
    ];
  }

  // ============================================================
  // POPULAR
  // ============================================================

  Widget _popular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POPULAR',
          style: TextStyle(
            color: DLogColors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('Engine', Icons.settings_rounded),
              _chip('Brakes', Icons.stop_circle_outlined),
              _chip('Tyres', Icons.tire_repair_outlined),
              _chip('Battery', Icons.battery_alert_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          _searchController.text = title;
          setState(() => _search = title);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF11171A),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFF283136),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: DLogColors.grey,
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: DLogColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: DLogColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: DLogColors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WARNING SECTION
  // ============================================================

  Widget _warningSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF283136),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DLogColors.burgundy.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: DLogColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warning Lights',
                      style: TextStyle(
                        color: DLogColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap a light to understand it.',
                      style: TextStyle(
                        color: DLogColors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.touch_app_outlined,
                color: DLogColors.grey,
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: warnings.map(_warningCard).toList(),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(WarningItem item) {
    final expanded = _expandedWarning == item.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedWarning =
                expanded ? null : item.title;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: expanded
                ? const Color(0xFF1A2024)
                : const Color(0xFF0E1417),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: expanded
                  ? DLogColors.burgundy
                  : const Color(0xFF283136),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: DLogColors.burgundy
                          .withValues(alpha: 0.13),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: DLogColors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: DLogColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DLogColors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: DLogColors.grey,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 13),
                _infoBox(
                  'WHAT IT MEANS',
                  item.meaning,
                ),
                const SizedBox(height: 8),
                _infoBox(
                  'WHAT TO DO',
                  item.action,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '●  ${item.severity}',
                    style: TextStyle(
                      color: _severity(item.severity),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SYSTEM GRID
  // ============================================================

  Widget _systemGrid(List<CategoryItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, index) {
        final item = items[index];

        return GestureDetector(
          onTap: () => _showCategory(item),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF11171A),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFF283136),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: DLogColors.burgundy
                        .withValues(alpha: 0.13),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: Icon(
                    item.icon,
                    color: DLogColors.white,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DLogColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '${item.count} topics',
                      style: const TextStyle(
                        color: DLogColors.grey,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: DLogColors.grey,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MORE TO EXPLORE
  // ============================================================

  Widget _secondarySystems() {
    return Column(
      children: systems
          .skip(6)
          .map(
            (item) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _showCategory(item),
                child: Container(
                  height: 70,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11171A),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF283136),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: DLogColors.burgundy
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(13),
                        ),
                        child: Icon(
                          item.icon,
                          color: DLogColors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: DLogColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${item.count}',
                        style: const TextStyle(
                          color: DLogColors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: DLogColors.grey,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ============================================================
  // CATEGORY SHEET
  // ============================================================

  void _showCategory(CategoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101518),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF424A4F),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: DLogColors.burgundy
                            .withValues(alpha: 0.13),
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                      child: Icon(
                        item.icon,
                        color: DLogColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: DLogColors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.count} topics',
                          style: const TextStyle(
                            color: DLogColors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...item.topics.map(
                  (topic) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);

                        Future.delayed(
                          const Duration(
                            milliseconds: 180,
                          ),
                          () {
                            if (mounted) {
                              _showTopic(
                                item.title,
                                topic,
                              );
                            }
                          },
                        );
                      },
                      child: Container(
                        height: 50,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1012),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFF283136),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration:
                                  const BoxDecoration(
                                color:
                                    DLogColors.burgundyBright,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                topic,
                                style: const TextStyle(
                                  color:
                                      DLogColors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons
                                  .arrow_forward_ios_rounded,
                              color: DLogColors.grey,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // TOPIC INFORMATION
  // ============================================================

  void _showTopic(
    String category,
    String topic,
  ) {
    final info = topicInfo[topic];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101518),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF424A4F),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: DLogColors.burgundyBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  topic,
                  style: const TextStyle(
                    color: DLogColors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _infoBox(
                  'WHAT IT IS',
                  info?.what ?? 'Vehicle component information.',
                ),
                const SizedBox(height: 9),
                _infoBox(
                  'WHY IT MATTERS',
                  info?.why ?? 'It contributes to normal vehicle operation.',
                ),
                const SizedBox(height: 9),
                _infoBox(
                  'GOOD TO KNOW',
                  info?.good ?? 'Follow the vehicle manufacturer recommendations.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBox(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1012),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF283136),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DLogColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: DLogColors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  List<Widget> _searchResults() {
    final ws = filteredWarnings;
    final ss = filteredSystems;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          18,
          26,
          18,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _sectionTitle(
            'SEARCH RESULTS',
            '${ws.length + ss.length} results found.',
          ),
        ),
      ),
      if (ws.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _warningSectionSearch(ws),
          ),
        ),
      if (ss.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            30,
          ),
          sliver: SliverToBoxAdapter(
            child: _systemGrid(ss),
          ),
        ),
      if (ws.isEmpty && ss.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(30),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.search_off_rounded,
                    color: DLogColors.grey,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nothing found',
                    style: TextStyle(
                      color: DLogColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Widget _warningSectionSearch(
    List<WarningItem> items,
  ) {
    return Column(
      children: items.map(_warningCard).toList(),
    );
  }

  // ============================================================
  // SEVERITY
  // ============================================================

  Color _severity(String value) {
    if (value == 'High priority') {
      return DLogColors.burgundyBright;
    }

    if (value == 'Check soon') {
      return const Color(0xFFD3A85C);
    }

    return DLogColors.white;
  }
}

// ============================================================================
// MODELS
// ============================================================================

class WarningItem {
  final String title;
  final String description;
  final IconData icon;
  final String severity;
  final String meaning;
  final String action;

  const WarningItem(
    this.title,
    this.description,
    this.icon,
    this.severity,
    this.meaning,
    this.action,
  );
}

class CategoryItem {
  final String title;
  final IconData icon;
  final int count;
  final List<String> topics;

  const CategoryItem(
    this.title,
    this.icon,
    this.count,
    this.topics,
  );
}

class TopicInfo {
  final String what;
  final String why;
  final String good;

  const TopicInfo({
    required this.what,
    required this.why,
    required this.good,
  });
}

// ============================================================================
// TOPIC INFORMATION
// ============================================================================

const Map<String, TopicInfo> topicInfo = {
  // ENGINE
  'How the engine works': TopicInfo(
    what:
        'The engine converts fuel and air into mechanical energy that powers the vehicle.',
    why:
        'It is the primary source of power for the vehicle.',
    good:
        'Regular servicing helps maintain lubrication, cooling and engine performance.',
  ),

  'Engine oil': TopicInfo(
    what:
        'Engine oil lubricates moving components and helps control friction and heat.',
    why:
        'Insufficient or degraded oil can increase engine wear.',
    good:
        'Use the correct oil grade and follow the recommended service interval.',
  ),

  'Air intake': TopicInfo(
    what:
        'The air intake supplies the engine with air needed for combustion.',
    why:
        'Restricted airflow can affect engine performance and efficiency.',
    good:
        'The air filter should be inspected and replaced according to the maintenance schedule.',
  ),

  'Spark plugs': TopicInfo(
    what:
        'Spark plugs create the spark that ignites the air-fuel mixture in petrol engines.',
    why:
        'Worn plugs can contribute to misfires and reduced performance.',
    good:
        'Replacement timing depends on the vehicle and spark-plug type.',
  ),

  'Belts & timing': TopicInfo(
    what:
        'Engine belts transfer mechanical power, while timing components synchronise engine operation.',
    why:
        'A damaged timing component can cause serious engine problems on some engines.',
    good:
        'Follow the manufacturer maintenance schedule for inspection and replacement.',
  ),

  'Common engine problems': TopicInfo(
    what:
        'Engine problems can involve lubrication, ignition, airflow, cooling or electronic systems.',
    why:
        'Early attention can prevent a small problem from becoming more serious.',
    good:
        'Do not ignore unusual sounds, smoke, overheating or warning lights.',
  ),

  // BRAKES
  'Brake pads': TopicInfo(
    what:
        'Brake pads create friction against the brake disc to slow the vehicle.',
    why:
        'Worn pads can reduce braking performance.',
    good:
        'Brake-pad life varies according to driving conditions and habits.',
  ),

  'Brake discs & drums': TopicInfo(
    what:
        'Discs and drums work with pads or shoes to slow the vehicle.',
    why:
        'Excessive wear or heat damage can affect braking.',
    good:
        'Inspect them during brake servicing.',
  ),

  'Brake fluid': TopicInfo(
    what:
        'Brake fluid transfers hydraulic pressure through the braking system.',
    why:
        'Contaminated or degraded fluid can affect braking performance.',
    good:
        'Use the exact fluid specification recommended for the vehicle.',
  ),

  'ABS': TopicInfo(
    what:
        'ABS helps prevent wheels from locking during hard braking.',
    why:
        'It helps the driver maintain steering control during emergency braking.',
    good:
        'A persistent ABS warning should be inspected.',
  ),

  'Brake warning signs': TopicInfo(
    what:
        'Warning signs include unusual noises, vibration, pulling or a soft pedal.',
    why:
        'Changes in braking behaviour can indicate wear or a system fault.',
    good:
        'Any significant change in braking should be checked promptly.',
  ),

  // WHEELS
  'Tyre pressure': TopicInfo(
    what:
        'Tyre pressure is the amount of air inside the tyre.',
    why:
        'Incorrect pressure affects handling, braking and tyre wear.',
    good:
        'Check pressure when tyres are cold and follow the vehicle specification.',
  ),

  'Tyre tread': TopicInfo(
    what:
        'Tread provides the contact pattern that helps maintain grip with the road.',
    why:
        'Insufficient tread can reduce wet-road traction.',
    good:
        'Inspect tread condition regularly.',
  ),

  'Wheel alignment': TopicInfo(
    what:
        'Wheel alignment sets the angles of the wheels relative to the vehicle and road.',
    why:
        'Incorrect alignment can cause uneven wear and handling problems.',
    good:
        'Uneven tyre wear or pulling can indicate an alignment issue.',
  ),

  'Wheel balancing': TopicInfo(
    what:
        'Wheel balancing distributes weight evenly around a rotating wheel.',
    why:
        'Poor balance can cause vibration and uneven tyre wear.',
    good:
        'Balancing is commonly checked when tyres are installed.',
  ),

  'Suspension basics': TopicInfo(
    what:
        'Suspension connects the wheels to the vehicle and controls movement.',
    why:
        'It contributes to stability, comfort and handling.',
    good:
        'Unusual bouncing, knocking or uneven tyre wear may indicate a problem.',
  ),

  // ELECTRICAL
  'Battery': TopicInfo(
    what:
        'The battery stores electrical energy for starting and vehicle electrical systems.',
    why:
        'A weak battery can cause starting and electrical problems.',
    good:
        'Battery condition depends on age, usage and charging performance.',
  ),

  'Alternator': TopicInfo(
    what:
        'The alternator generates electrical power while the engine is running.',
    why:
        'It helps keep the battery charged.',
    good:
        'A charging warning can indicate an alternator or charging-system issue.',
  ),

  'Starter motor': TopicInfo(
    what:
        'The starter motor turns the engine when the vehicle is started.',
    why:
        'A starter fault can prevent the engine from cranking.',
    good:
        'Clicking or slow cranking can indicate a starting-system problem.',
  ),

  'Vehicle electronics': TopicInfo(
    what:
        'Modern vehicles use electronic control units and sensors for many functions.',
    why:
        'Electronic faults can affect engine, safety and comfort systems.',
    good:
        'Warning lights can indicate when an electronic system needs attention.',
  ),

  // COOLING
  'Engine coolant': TopicInfo(
    what:
        'Coolant circulates through the engine to help control temperature.',
    why:
        'Low or degraded coolant can contribute to overheating.',
    good:
        'Use the correct coolant specification.',
  ),

  'Radiator': TopicInfo(
    what:
        'The radiator transfers heat from engine coolant to the surrounding air.',
    why:
        'A damaged or restricted radiator can reduce cooling performance.',
    good:
        'Persistent overheating or cooling-system leaks require attention.',
  ),

  'Transmission fluid': TopicInfo(
    what:
        'Transmission fluid lubricates and helps operate transmission components.',
    why:
        'Incorrect or degraded fluid can affect transmission operation.',
    good:
        'Use the exact fluid specification recommended for the transmission.',
  ),

  'Fluid warning signs': TopicInfo(
    what:
        'Warning signs include leaks, unusual levels or changes in fluid condition.',
    why:
        'Fluid loss can affect lubrication, cooling or hydraulic systems.',
    good:
        'Do not ignore persistent leaks or sudden fluid-level changes.',
  ),

  // POWERTRAIN
  'Transmission': TopicInfo(
    what:
        'The transmission transfers engine power to the wheels through different ratios.',
    why:
        'It affects acceleration, efficiency and drivability.',
    good:
        'Unusual shifting, slipping or noises should be inspected.',
  ),

  'Automatic transmission': TopicInfo(
    what:
        'An automatic transmission changes gear ratios automatically.',
    why:
        'It allows the driver to operate without manually selecting each gear.',
    good:
        'Correct fluid and servicing are important for operation.',
  ),

  'CVT': TopicInfo(
    what:
        'A CVT uses a continuously changing ratio rather than traditional fixed gears.',
    why:
        'It can keep the engine within an efficient operating range.',
    good:
        'Use the manufacturer-specified CVT fluid and service schedule.',
  ),

  'DCT': TopicInfo(
    what:
        'A Dual-Clutch Transmission uses two clutches to manage gear sets.',
    why:
        'It allows fast gear changes while maintaining power delivery.',
    good:
        'DCT servicing requirements vary by vehicle design.',
  ),

  // CLIMATE
  'Air conditioning': TopicInfo(
    what:
        'The air-conditioning system cools and dehumidifies cabin air.',
    why:
        'It improves comfort and helps manage cabin humidity.',
    good:
        'Weak cooling, unusual smells or noises can indicate a problem.',
  ),

  'Cabin filter': TopicInfo(
    what:
        'The cabin filter helps remove dust and particles from incoming air.',
    why:
        'A clogged filter can reduce airflow.',
    good:
        'Replacement timing depends on the vehicle and operating environment.',
  ),

  'Blower system': TopicInfo(
    what:
        'The blower moves conditioned air through the cabin.',
    why:
        'A blower problem can reduce or eliminate airflow.',
    good:
        'Weak airflow can indicate a filter, blower or electrical issue.',
  ),

  // MAINTENANCE
  'Service intervals': TopicInfo(
    what:
        'Service intervals specify when particular maintenance tasks should be performed.',
    why:
        'Following the appropriate schedule helps manage wear.',
    good:
        'Intervals can depend on both time and distance.',
  ),

  'Oil changes': TopicInfo(
    what:
        'An oil change replaces used engine oil with fresh oil of the correct specification.',
    why:
        'Fresh oil helps protect engine components.',
    good:
        'Follow the vehicle maintenance schedule and specified oil grade.',
  ),

  'Fluid checks': TopicInfo(
    what:
        'Fluid checks inspect important vehicle fluids and their levels or condition.',
    why:
        'Correct fluid levels support cooling, lubrication and hydraulic systems.',
    good:
        'Different fluids have different specifications.',
  ),

  'Wear items': TopicInfo(
    what:
        'Wear items gradually wear during normal vehicle use.',
    why:
        'Monitoring them helps prevent degraded performance.',
    good:
        'Examples include brake pads, tyres, filters and certain belts.',
  ),

  'Inspection basics': TopicInfo(
    what:
        'A basic inspection checks accessible vehicle components for abnormal conditions.',
    why:
        'Regular checks can identify problems earlier.',
    good:
        'Look for leaks, warning lights, unusual noises and tyre issues.',
  ),

  'Maintenance records': TopicInfo(
    what:
        'Maintenance records document services, repairs and replacements.',
    why:
        'They help drivers understand the vehicle service history.',
    good:
        'Keeping records makes future maintenance tracking easier.',
  ),
};