import 'package:flutter/material.dart';

import '../models/team_member.dart';
import '../models/competency.dart';
import '../services/team_repository.dart';

enum MatrixMode { byDancer, byDance }

class SkillsMatrixView extends StatefulWidget {
  const SkillsMatrixView({Key? key})
    : super(key: const Key('skills_matrix_view'));

  @override
  State<SkillsMatrixView> createState() => _SkillsMatrixViewState();
}

class _SkillsMatrixViewState extends State<SkillsMatrixView> {
  final TeamRepository _teamRepository = TeamRepository();

  bool _isLoading = true;
  MatrixMode _currentMode = MatrixMode.byDance;

  // Catalog and Roster Data
  List<TeamMember> _members = [];
  List<String> _danceList = [];
  List<Competency> _activeCompetencies = [];

  // Currently Selected Filters
  String? _selectedDance;
  TeamMember? _selectedMember;

  // Proficiency scale
  final List<String> _proficiencyLevels = ['None', 'L', 'Q', 'M'];

  // Special Role Position Markers
  static const int musicianPosition = 0;
  static const int mabPosition = 98;
  static const int mafPosition = 99;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Initial load of team members and dance catalog
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _teamRepository.fetchTeamMembers();
      final dances = await _teamRepository.fetchDanceNames();

      setState(() {
        _members = members;
        _danceList = dances;

        if (_members.isNotEmpty) _selectedMember = _members.first;
        if (_danceList.isNotEmpty) _selectedDance = _danceList.first;
      });

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

  /// Fetch competencies based on active matrix view mode
  Future<void> _refreshCompetencies() async {
    if (_currentMode == MatrixMode.byDance && _selectedDance != null) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update proficiency: $e')),
        );
      }
    }
  }

  /// Helper to map proficiency code to badge colors
  Color _getBadgeColor(String level) {
    switch (level) {
      case 'L':
        return Colors.orange.shade300;
      case 'Q':
        return Colors.green.shade400;
      case 'M':
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
        proficiencyLevel: 'None',
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

    return Scaffold(
      appBar: AppBar(title: const Text('Skills Matrix')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Toggle Switch: By Dance vs By Dancer
          Center(
            child: SegmentedButton<MatrixMode>(
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
              selected: {_currentMode},
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
            child: _currentMode == MatrixMode.byDance
                ? _buildDanceDropdown()
                : _buildDancerDropdown(),
          ),
          const Divider(height: 24),

          // Active View Content Table
          Expanded(
            child: _currentMode == MatrixMode.byDance
                ? _buildByDanceTable()
                : _buildByDancerTable(),
          ),
        ],
      ),
    );
  }

  /// Dropdown for selecting active Dance
  Widget _buildDanceDropdown() {
    return Row(
      children: [
        const Text(
          'Select Dance: ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
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
          ),
        ),
      ],
    );
  }

  /// Dropdown for selecting active Team Member
  Widget _buildDancerDropdown() {
    return Row(
      children: [
        const Text(
          'Select Member: ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<TeamMember>(
            value: _selectedMember,
            isExpanded: true,
            items: _members.map((member) {
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
          ),
        ),
      ],
    );
  }

  /// Matrix View 1: BY DANCE (All members on rows)
  Widget _buildByDanceTable() {
    if (_selectedDance == null) {
      return const Center(child: Text('No dance selected.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16.0,
          columns: [
            const DataColumn(
              label: Text(
                'Team Member',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Musician',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text('MAF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('MAB', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...List.generate(
              8,
              (i) => DataColumn(
                label: Text(
                  'Pos ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          rows: _members.map((member) {
            final bool isMusician = member.isMusician;

            return DataRow(
              cells: [
                // Column 1: Name and Instrument Subtitle (if applicable)
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
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

                // Column 2: Musician Position (0)
                // Enabled only if member is a musician, disabled ('-') for dancers
                if (isMusician)
                  _buildCell(member.id, _selectedDance!, musicianPosition)
                else
                  _buildDisabledCell(),

                // Positional Columns: Disabled for musicians, active for dancers
                if (isMusician) ...[
                  _buildDisabledCell(),
                  _buildDisabledCell(),
                  ...List.generate(8, (_) => _buildDisabledCell()),
                ] else ...[
                  _buildCell(member.id, _selectedDance!, mafPosition),
                  _buildCell(member.id, _selectedDance!, mabPosition),
                  ...List.generate(
                    8,
                    (i) => _buildCell(member.id, _selectedDance!, i + 1),
                  ),
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

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16.0,
          columns: [
            const DataColumn(
              label: Text(
                'Dance Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Musician',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text('MAF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const DataColumn(
              label: Text('MAB', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...List.generate(
              8,
              (i) => DataColumn(
                label: Text(
                  'Pos ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          rows: _danceList.map((dance) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    dance,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),

                // Musician position cell (Pos 0)
                // Active ONLY if the selected member is a musician
                if (isMusician)
                  _buildCell(_selectedMember!.id, dance, musicianPosition)
                else
                  _buildDisabledCell(),

                // Positional Columns: Disabled if member is a musician, active for dancers
                if (isMusician) ...[
                  _buildDisabledCell(),
                  _buildDisabledCell(),
                  ...List.generate(8, (_) => _buildDisabledCell()),
                ] else ...[
                  _buildCell(_selectedMember!.id, dance, mafPosition),
                  _buildCell(_selectedMember!.id, dance, mabPosition),
                  ...List.generate(
                    8,
                    (i) => _buildCell(_selectedMember!.id, dance, i + 1),
                  ),
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
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _getBadgeColor(level),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            level == 'None' ? '-' : level,
            style: TextStyle(
              color: level == 'None' ? Colors.black54 : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
