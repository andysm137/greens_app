import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_member.dart';
import '../models/competency.dart';
import '../services/team_repository.dart';

enum MatrixMode { byDancer, byDance }

class SkillsMatrixView extends StatefulWidget {
  final TeamMember currentMember;
  final String? initialDancerId;
  final String? highlightDanceName;

  const SkillsMatrixView({
    Key? key,
    required this.currentMember,
    this.initialDancerId,
    this.highlightDanceName,
  }) : super(key: const Key('skills_matrix_view'));

  @override
  State<SkillsMatrixView> createState() => _SkillsMatrixViewState();
}

class _SkillsMatrixViewState extends State<SkillsMatrixView>
    with SingleTickerProviderStateMixin {
  final TeamRepository _teamRepository = TeamRepository();

  bool _isLoading = true;
  MatrixMode _currentMode = MatrixMode.byDance;

  // Catalog and Roster Data
  List<TeamMember> _members = [];
  List<String> _danceList = [];
  List<Map<String, dynamic>> _danceCatalogDetails = [];
  Map<String, int> _dancePositionCounts = {};
  List<Competency> _activeCompetencies = [];

  // Currently Selected Filters
  String? _selectedDance;
  TeamMember? _selectedMember;
  String? _highlightedDanceName;
  late final AnimationController _highlightFadeController =
      AnimationController(vsync: this, duration: const Duration(seconds: 15))
        ..addListener(() {
          if (mounted) setState(() {});
        });

  // Proficiency scale
  final List<String> _proficiencyLevels = ['-', 'L', 'YP', 'Y'];

  // Keeps each frozen header's horizontal scroll in step with its body.
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  bool _syncingHScroll = false;

  // Special Role Position Markers
  static const int musicianPosition = 0;
  static const int mabPosition = 98;
  static const int mafPosition = 99;

  @override
  void initState() {
    super.initState();
    if (!widget.currentMember.isLeader && !widget.currentMember.isAdmin) {
      _currentMode = MatrixMode.byDancer;
    }
    _highlightedDanceName = widget.highlightDanceName;
    if (_highlightedDanceName != null) {
      _highlightFadeController.forward(from: 0);
    }
    // Captured now, synchronously: the parent may clear widget.initialDancerId
    // a frame later, before the awaits below finish.
    _loadInitialData(widget.initialDancerId);
    _headerHScroll.addListener(() => _syncHScroll(_headerHScroll, _bodyHScroll));
    _bodyHScroll.addListener(() => _syncHScroll(_bodyHScroll, _headerHScroll));
  }

  @override
  void didUpdateWidget(covariant SkillsMatrixView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The Key is constant across tab switches, so a new deep-link request
    // arrives here rather than through a fresh initState.
    final dancerId = widget.initialDancerId;
    if (dancerId != null && dancerId != oldWidget.initialDancerId) {
      _applyDancerDeepLink(dancerId);
    }
    final danceName = widget.highlightDanceName;
    if (danceName != null && danceName != oldWidget.highlightDanceName) {
      setState(() => _highlightedDanceName = danceName);
      _highlightFadeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _highlightFadeController.dispose();
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    super.dispose();
  }

  void _syncHScroll(ScrollController from, ScrollController to) {
    if (_syncingHScroll || !to.hasClients) return;
    _syncingHScroll = true;
    to.jumpTo(from.offset);
    _syncingHScroll = false;
  }

  void _applyDancerDeepLink(String dancerId) {
    if (!widget.currentMember.isLeader && !widget.currentMember.isAdmin) {
      return;
    }
    if (_members.isEmpty) return;
    setState(() {
      _currentMode = MatrixMode.byDancer;
      _selectedMember = _members.firstWhere(
        (member) => member.id == dancerId,
        orElse: () => _selectedMember ?? widget.currentMember,
      );
    });
    _refreshCompetencies();
  }

  /// Initial load of team members and dance catalog
  Future<void> _loadInitialData([String? requestedDancerId]) async {
    setState(() => _isLoading = true);
    try {
      final members = await _teamRepository.fetchTeamMembers();
      final dances = await _teamRepository.fetchDanceNames();
      final danceDetails = await _teamRepository.fetchDanceCatalog();

      setState(() {
        _members = List<TeamMember>.from(members)..sort(_compareDancersFirst);
        _danceList = dances;
        _danceCatalogDetails = danceDetails;
        _dancePositionCounts = {
          for (final dance in danceDetails)
            dance['dance_name'] as String: dance['standard_positions'] as int,
        };

        if (_members.isNotEmpty) {
          _selectedMember =
              widget.currentMember.isLeader || widget.currentMember.isAdmin
              ? _members.first
              : _members.firstWhere(
                  (member) => member.id == widget.currentMember.id,
                  orElse: () => widget.currentMember,
                );
        }
        if (_danceList.isNotEmpty) _selectedDance = _danceList.first;
      });

      if (requestedDancerId != null) {
        _applyDancerDeepLink(requestedDancerId);
      }

      await _refreshCompetencies();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matrix data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _selectedDancePositionCount =>
      _dancePositionCounts[_selectedDance] ?? 8;

  Future<void> _jumpToDancer(TeamMember member) async {
    setState(() {
      _currentMode = MatrixMode.byDancer;
      _selectedMember = member;
    });
    await _refreshCompetencies();
  }

  Future<void> _jumpToDance(String danceName) async {
    final isMember =
        !widget.currentMember.isLeader && !widget.currentMember.isAdmin;
    if (isMember) return; // By Dance view is Leader/Admin only.
    setState(() {
      _currentMode = MatrixMode.byDance;
      _selectedDance = danceName;
    });
    await _refreshCompetencies();
  }

  // Dancers group first, then Musicians, each sorted alphabetically by name.
  int _compareDancersFirst(TeamMember a, TeamMember b) {
    if (a.isMusician != b.isMusician) {
      return a.isMusician ? 1 : -1;
    }
    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  }

  int _positionCountForDance(String danceName) =>
      _dancePositionCounts[danceName] ?? 8;

  bool _danceHasRole(String danceName, String role) {
    for (final dance in _danceCatalogDetails) {
      if (dance['dance_name'] == danceName) {
        return role == 'MAF'
            ? dance['has_maf'] == true
            : dance['has_mab'] == true;
      }
    }
    return false;
  }

  /// Fetch competencies based on active matrix view mode
  Future<void> _refreshCompetencies() async {
    final isMember =
        !widget.currentMember.isLeader && !widget.currentMember.isAdmin;
    if (!isMember &&
        _currentMode == MatrixMode.byDance &&
        _selectedDance != null) {
      final comps = await _teamRepository.fetchCompetenciesForDance(
        _selectedDance!,
      );
      setState(() => _activeCompetencies = comps);
    } else if (_currentMode == MatrixMode.byDancer && _selectedMember != null) {
      final comps = await _teamRepository.fetchCompetenciesForMember(
        _selectedMember!.id,
      );
      setState(() => _activeCompetencies = comps);
    }
  }

  /// Cycle competency proficiency levels (None -> L -> Q -> M)
  Future<void> _updateProficiency({
    required String memberId,
    required String danceName,
    required int positionNumber,
    required String currentLevel,
  }) async {
    final currentIndex = _proficiencyLevels.indexOf(currentLevel);
    final nextIndex = (currentIndex + 1) % _proficiencyLevels.length;
    final newLevel = _proficiencyLevels[nextIndex];

    try {
      await _teamRepository.upsertCompetency(
        memberId: memberId,
        danceName: danceName,
        positionNumber: positionNumber,
        proficiencyLevel: newLevel,
      );
      await _refreshCompetencies();
      if (memberId == widget.currentMember.id) {
        await _dispatchCompetencyNotification(
          danceName: danceName,
          positionNumber: positionNumber,
          oldLevel: currentLevel,
          newLevel: newLevel,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update proficiency: $e')),
        );
      }
    }
  }

  String _positionLabel(int positionNumber) {
    switch (positionNumber) {
      case musicianPosition:
        return 'Musician';
      case mafPosition:
        return 'MAF';
      case mabPosition:
        return 'MAB';
      default:
        return 'Position $positionNumber';
    }
  }

  Future<void> _dispatchCompetencyNotification({
    required String danceName,
    required int positionNumber,
    required String oldLevel,
    required String newLevel,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'notification_type': 'competency_updated',
          'member_id': widget.currentMember.id,
          'dance_name': danceName,
          'position_label': _positionLabel(positionNumber),
          'old_level': oldLevel,
          'new_level': newLevel,
        },
      );
    } catch (_) {
      // Notification delivery must not block a competency update.
    }
  }

  /// Helper to map proficiency code to badge colors
  Color _getBadgeColor(String level) {
    switch (level) {
      case 'L':
        return Colors.orange.shade300;
      case 'YP':
        return Colors.purple.shade300;
      case 'Y':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade300;
    }
  }

  /// Helper to lookup existing proficiency score
  String _getProficiency(
    String memberId,
    String danceName,
    int positionNumber,
  ) {
    final match = _activeCompetencies.firstWhere(
      (c) =>
          c.memberId == memberId &&
          c.danceName == danceName &&
          c.positionNumber == positionNumber,
      orElse: () => Competency(
        id: '',
        memberId: memberId,
        danceName: danceName,
        positionNumber: positionNumber,
        proficiencyLevel: '-',
      ),
    );
    return match.proficiencyLevel;
  }

  /// Helper widget for disabled matrix cells
  DataCell _buildDisabledCell() {
    return const DataCell(
      Center(
        child: Text('-', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  static const double _nameColWidth = 160;
  static const double _cellColWidth = 52;
  static const double _musicianColWidth = 80;

  Widget _fixedCell(double width, Widget child, {bool alignLeft = false}) {
    return SizedBox(
      width: width,
      height: 43,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Align(
          alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _positionHeaderLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final isMember =
        !widget.currentMember.isLeader && !widget.currentMember.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Skills Matrix')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Toggle Switch: By Dance vs By Dancer
          if (!isMember)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 0),
              child: SegmentedButton<MatrixMode>(
                style: SegmentedButton.styleFrom(
                  visualDensity: const VisualDensity(vertical: -2),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
                segments: const [
                  ButtonSegment<MatrixMode>(
                    value: MatrixMode.byDance,
                    label: Text('By Dance'),
                    icon: Icon(Icons.grid_on),
                  ),
                  ButtonSegment<MatrixMode>(
                    value: MatrixMode.byDancer,
                    label: Text('By Dancer'),
                    icon: Icon(Icons.person),
                  ),
                ],
                selected: {isMember ? MatrixMode.byDancer : _currentMode},
                expandedInsets: isCompact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 24),
                onSelectionChanged: (newSelection) async {
                  setState(() {
                    _currentMode = newSelection.first;
                  });
                  await _refreshCompetencies();
                },
              ),
            ),
          const SizedBox(height: 12),

          // Dropdown Filter Selector Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: isMember || _currentMode == MatrixMode.byDancer
                ? _buildDancerDropdown()
                : _buildDanceDropdown(),
          ),
          const Divider(height: 24),

          // Active View Content Table
          Expanded(
            child: isMember || _currentMode == MatrixMode.byDancer
                ? _buildByDancerTable()
                : _buildByDanceTable(),
          ),
        ],
      ),
    );
  }

  /// Dropdown for selecting active Dance
  Widget _buildDanceDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final selector = DropdownButton<String>(
          value: _selectedDance,
          isExpanded: true,
          items: _danceList.map((dance) {
            return DropdownMenuItem(value: dance, child: Text(dance));
          }).toList(),
          onChanged: (val) async {
            if (val != null) {
              setState(() => _selectedDance = val);
              await _refreshCompetencies();
            }
          },
        );

        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Dance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  selector,
                ],
              )
            : Row(
                children: [
                  const Text(
                    'Select Dance: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: selector),
                ],
              );
      },
    );
  }

  /// Dropdown for selecting active Team Member
  Widget _buildDancerDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final isMember =
            !widget.currentMember.isLeader && !widget.currentMember.isAdmin;
        final selectableMembers = isMember
            ? [_selectedMember ?? widget.currentMember]
            : _members;
        final selector = DropdownButton<TeamMember>(
          value: _selectedMember,
          isExpanded: true,
          items: selectableMembers.map((member) {
            return DropdownMenuItem(
              value: member,
              child: Text(
                member.isMusician
                    ? '${member.fullName} (${member.instruments})'
                    : member.fullName,
              ),
            );
          }).toList(),
          onChanged: (val) async {
            if (val != null) {
              setState(() => _selectedMember = val);
              await _refreshCompetencies();
            }
          },
        );

        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Member',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  selector,
                ],
              )
            : Row(
                children: [
                  const Text(
                    'Select Member: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: selector),
                ],
              );
      },
    );
  }

  Widget _memberNameCell(TeamMember member, bool isMusician) {
    return InkWell(
      onTap: () => _jumpToDancer(member),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            member.fullName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (isMusician && member.instruments != null)
            Text(
              member.instruments!,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.purple.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  /// Matrix View 1: BY DANCE (All members on rows)
  Widget _buildByDanceTable() {
    if (_selectedDance == null) {
      return const Center(child: Text('No dance selected.'));
    }

    final hasMaf = _danceHasRole(_selectedDance!, 'MAF');
    final hasMab = _danceHasRole(_selectedDance!, 'MAB');
    final positionCount = _selectedDancePositionCount;

    final headerRow = Row(
      children: [
        _fixedCell(
          _nameColWidth,
          const Text(
            'Team Member',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          alignLeft: true,
        ),
        ...List.generate(
          positionCount,
          (i) => _fixedCell(_cellColWidth, _positionHeaderLabel('Pos ${i + 1}')),
        ),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAF')),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAB')),
        _fixedCell(
          _musicianColWidth,
          const Text(
            'Musician',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    return Column(
      children: [
        // Frozen header: scrolls horizontally in step with the body, never vertically.
        SingleChildScrollView(
          controller: _headerHScroll,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: headerRow,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _bodyHScroll,
              scrollDirection: Axis.horizontal,
              child: Column(
                children: _members.map((member) {
                  final bool isMusician = member.isMusician;
                  return Row(
                    children: [
                      _fixedCell(
                        _nameColWidth,
                        _memberNameCell(member, isMusician),
                        alignLeft: true,
                      ),
                      if (isMusician) ...[
                        ...List.generate(
                          positionCount,
                          (_) => _fixedCell(
                            _cellColWidth,
                            _buildDisabledCell().child,
                          ),
                        ),
                        _fixedCell(_cellColWidth, _buildDisabledCell().child),
                        _fixedCell(_cellColWidth, _buildDisabledCell().child),
                        _fixedCell(
                          _musicianColWidth,
                          _buildCell(
                            member.id,
                            _selectedDance!,
                            musicianPosition,
                          ).child,
                        ),
                      ] else ...[
                        ...List.generate(
                          positionCount,
                          (i) => _fixedCell(
                            _cellColWidth,
                            _buildCell(member.id, _selectedDance!, i + 1).child,
                          ),
                        ),
                        _fixedCell(
                          _cellColWidth,
                          (hasMaf
                                  ? _buildCell(
                                      member.id,
                                      _selectedDance!,
                                      mafPosition,
                                    )
                                  : _buildDisabledCell())
                              .child,
                        ),
                        _fixedCell(
                          _cellColWidth,
                          (hasMab
                                  ? _buildCell(
                                      member.id,
                                      _selectedDance!,
                                      mabPosition,
                                    )
                                  : _buildDisabledCell())
                              .child,
                        ),
                        _fixedCell(_musicianColWidth, _buildDisabledCell().child),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Matrix View 2: BY DANCER (All dances on rows)
  Widget _buildByDancerTable() {
    if (_selectedMember == null) {
      return const Center(child: Text('No team member selected.'));
    }

    final bool isMusician = _selectedMember!.isMusician;
    final bool isMember =
        !widget.currentMember.isLeader && !widget.currentMember.isAdmin;

    final headerRow = Row(
      children: [
        _fixedCell(
          _nameColWidth,
          const Text(
            'Dance Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          alignLeft: true,
        ),
        ...List.generate(
          12,
          (i) => _fixedCell(_cellColWidth, _positionHeaderLabel('Pos ${i + 1}')),
        ),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAF')),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAB')),
        _fixedCell(
          _musicianColWidth,
          const Text(
            'Musician',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    return Column(
      children: [
        // Frozen header: scrolls horizontally in step with the body, never vertically.
        SingleChildScrollView(
          controller: _headerHScroll,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: headerRow,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _bodyHScroll,
              scrollDirection: Axis.horizontal,
              child: Column(
                children: _danceList.map((dance) {
                  final dancePositionCount = _positionCountForDance(dance);
                  final hasMaf = _danceHasRole(dance, 'MAF');
                  final hasMab = _danceHasRole(dance, 'MAB');
                  final isHighlighted = dance == _highlightedDanceName;

                  return Container(
                    color: isHighlighted
                        ? Colors.amber.shade100.withValues(
                            alpha: 1 - _highlightFadeController.value,
                          )
                        : null,
                    child: Row(
                      children: [
                        _fixedCell(
                          _nameColWidth,
                          InkWell(
                            onTap: isMember ? null : () => _jumpToDance(dance),
                            child: Text(
                              dance,
                              style: TextStyle(
                              fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: isMember
                                    ? null
                                    : TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          alignLeft: true,
                        ),
                        if (isMusician) ...[
                          ...List.generate(
                            12,
                            (_) => _fixedCell(
                              _cellColWidth,
                              _buildDisabledCell().child,
                            ),
                          ),
                          _fixedCell(_cellColWidth, _buildDisabledCell().child),
                          _fixedCell(_cellColWidth, _buildDisabledCell().child),
                          _fixedCell(
                            _musicianColWidth,
                            _buildCell(
                              _selectedMember!.id,
                              dance,
                              musicianPosition,
                            ).child,
                          ),
                        ] else ...[
                          ...List.generate(
                            12,
                            (i) => _fixedCell(
                              _cellColWidth,
                              (i < dancePositionCount
                                      ? _buildCell(
                                          _selectedMember!.id,
                                          dance,
                                          i + 1,
                                        )
                                      : _buildDisabledCell())
                                  .child,
                            ),
                          ),
                          _fixedCell(
                            _cellColWidth,
                            (hasMaf
                                    ? _buildCell(
                                        _selectedMember!.id,
                                        dance,
                                        mafPosition,
                                      )
                                    : _buildDisabledCell())
                                .child,
                          ),
                          _fixedCell(
                            _cellColWidth,
                            (hasMab
                                    ? _buildCell(
                                        _selectedMember!.id,
                                        dance,
                                        mabPosition,
                                      )
                                    : _buildDisabledCell())
                                .child,
                          ),
                          _fixedCell(
                            _musicianColWidth,
                            _buildDisabledCell().child,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Interactive Cell Widget for both views
  DataCell _buildCell(String memberId, String danceName, int positionNumber) {
    final level = _getProficiency(memberId, danceName, positionNumber);

    return DataCell(
      InkWell(
        onTap: () => _updateProficiency(
          memberId: memberId,
          danceName: danceName,
          positionNumber: positionNumber,
          currentLevel: level,
        ),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 43,
          child: Center(
            child: Container(
              height: 36,
              width: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _getBadgeColor(level),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                level == '-' ? '-' : level,
                style: TextStyle(
                  color: level == '-' ? Colors.black54 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
