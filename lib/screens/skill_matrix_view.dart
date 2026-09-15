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
    if (_highlightedDanceName != null)
      _highlightFadeController.forward(from: 0);
    // Captured now, synchronously: the parent may clear widget.initialDancerId
    // a frame later, before the awaits below finish.
    _loadInitialData(widget.initialDancerId);
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
    super.dispose();
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
        return Colors.green.shade400;
      case 'Y':
        return Colors.purple.shade300;
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

  /// Matrix View 1: BY DANCE (All members on rows)
  Widget _buildByDanceTable() {
    if (_selectedDance == null) {
      return const Center(child: Text('No dance selected.'));
    }

    final hasMaf = _danceHasRole(_selectedDance!, 'MAF');
    final hasMab = _danceHasRole(_selectedDance!, 'MAB');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          columns: [
            const DataColumn(
              label: Text(
                'Team Member',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...List.generate(
              _selectedDancePositionCount,
              (i) => DataColumn(
                label: Text(
                  'Pos ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const DataColumn(
              label: Text('MAF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('MAB', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text(
                'Musician',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _members.map((member) {
            final bool isMusician = member.isMusician;

            return DataRow(
              cells: [
                // Column 1: Name and Instrument Subtitle (if applicable)
                DataCell(
                  InkWell(
                    onTap: () => _jumpToDancer(member),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        if (isMusician && member.instruments != null)
                          Text(
                            member.instruments!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.purple.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Positional Columns: Disabled for musicians, active for dancers
                if (isMusician) ...[
                  ...List.generate(
                    _selectedDancePositionCount,
                    (_) => _buildDisabledCell(),
                  ),
                  _buildDisabledCell(),
                  _buildDisabledCell(),
                  _buildCell(member.id, _selectedDance!, musicianPosition),
                ] else ...[
                  ...List.generate(
                    _selectedDancePositionCount,
                    (i) => _buildCell(member.id, _selectedDance!, i + 1),
                  ),
                  hasMaf
                      ? _buildCell(member.id, _selectedDance!, mafPosition)
                      : _buildDisabledCell(),
                  hasMab
                      ? _buildCell(member.id, _selectedDance!, mabPosition)
                      : _buildDisabledCell(),
                  _buildDisabledCell(),
                ],
              ],
            );
          }).toList(),
        ),
      ),
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

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          columns: [
            const DataColumn(
              label: Text(
                'Dance Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...List.generate(
              12,
              (i) => DataColumn(
                label: Text(
                  'Pos ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const DataColumn(
              label: Text('MAF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('MAB', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text(
                'Musician',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _danceList.map((dance) {
            final dancePositionCount = _positionCountForDance(dance);
            final hasMaf = _danceHasRole(dance, 'MAF');
            final hasMab = _danceHasRole(dance, 'MAB');
            final isHighlighted = dance == _highlightedDanceName;

            return DataRow(
              color: isHighlighted
                  ? WidgetStateProperty.all(
                      Colors.amber.shade100.withValues(
                        alpha: 1 - _highlightFadeController.value,
                      ),
                    )
                  : null,
              cells: [
                DataCell(
                  InkWell(
                    onTap: isMember ? null : () => _jumpToDance(dance),
                    child: Text(
                      dance,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        decoration: isMember ? null : TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                // Positional Columns: Disabled if member is a musician, active for dancers
                if (isMusician) ...[
                  ...List.generate(12, (_) => _buildDisabledCell()),
                  _buildDisabledCell(),
                  _buildDisabledCell(),
                  _buildCell(_selectedMember!.id, dance, musicianPosition),
                ] else ...[
                  ...List.generate(
                    12,
                    (i) => i < dancePositionCount
                        ? _buildCell(_selectedMember!.id, dance, i + 1)
                        : _buildDisabledCell(),
                  ),
                  hasMaf
                      ? _buildCell(_selectedMember!.id, dance, mafPosition)
                      : _buildDisabledCell(),
                  hasMab
                      ? _buildCell(_selectedMember!.id, dance, mabPosition)
                      : _buildDisabledCell(),
                  _buildDisabledCell(),
                ],
              ],
            );
          }).toList(),
        ),
      ),
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
          height: 48,
          child: Center(
            child: Container(
              height: 40,
              width: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: _getBadgeColor(level),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                level == '-' ? '-' : level,
                style: TextStyle(
                  color: level == '-' ? Colors.black54 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
