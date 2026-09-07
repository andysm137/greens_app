// lib/screens/stage_builder_view.dart

import 'package:flutter/material.dart';

// 1. PLACE IMPORTS AT THE VERY TOP OF THE FILE
import '../services/team_repository.dart';
import '../models/team_member.dart';
import '../models/competency.dart';

class StageBuilderView extends StatefulWidget {
  final String danceName;
  final int standardPositions; // Must be 8 or 12
  final bool initialMaf;
  final bool initialMab;

  const StageBuilderView({
    super.key,
    required this.danceName,
    required this.standardPositions,
    this.initialMaf = false,
    this.initialMab = false,
  });

  @override
  State<StageBuilderView> createState() => _StageBuilderViewState();
}

class _StageBuilderViewState extends State<StageBuilderView> {
  late bool _hasMaf;
  late bool _hasMab;

  final Map<String, String> _assignedDancers = {};

  // 2. PLACE REPOSITORY INSTANCE VARIABLE HERE (Inside the State class)
  final TeamRepository _teamRepository = TeamRepository();

  @override
  void initState() {
    super.initState();
    _hasMaf = widget.initialMaf;
    _hasMab = widget.initialMab;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dance Formation: ${widget.danceName} (${widget.standardPositions}-Set)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  FilterChip(
                    label: const Text('MAF'),
                    selected: _hasMaf,
                    onSelected: (bool value) {
                      setState(() {
                        _hasMaf = value;
                        if (!value) _assignedDancers.remove('MAF');
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('MAB'),
                    selected: _hasMab,
                    onSelected: (bool value) {
                      setState(() {
                        _hasMab = value;
                        if (!value) _assignedDancers.remove('MAB');
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[150],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasMaf) ...[
                    _buildPositionCard('MAF', 'Middle Ahead Front'),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.standardPositions ~/ 2,
                      itemBuilder: (context, rowIndex) {
                        int leftPos = (rowIndex * 2) + 1;
                        int rightPos = (rowIndex * 2) + 2;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildPositionCard(
                                  leftPos.toString(),
                                  'Position $leftPos',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildPositionCard(
                                  rightPos.toString(),
                                  'Position $rightPos',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_hasMab) ...[
                    const SizedBox(height: 16),
                    _buildPositionCard('MAB', 'Middle Along Back'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(String positionKey, String label) {
    final assignedName = _assignedDancers[positionKey];
    final isSpecialRole = positionKey == 'MAF' || positionKey == 'MAB';

    return InkWell(
      onTap: () => _showDancerSelectionModal(positionKey, label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSpecialRole ? Colors.amber[50] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: assignedName != null ? Colors.indigo : Colors.grey.shade400,
            width: assignedName != null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSpecialRole ? Colors.amber[900] : Colors.grey[600],
                  ),
                ),
                Text(
                  assignedName ?? 'Unassigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: assignedName != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: assignedName != null
                        ? Colors.black87
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
            Icon(
              assignedName != null ? Icons.check_circle : Icons.person_add_alt,
              color: assignedName != null ? Colors.indigo : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 3. PLACE THE UPDATED MODAL METHOD HERE (Replacing the old mock version at the bottom)
  void _showDancerSelectionModal(String positionKey, String label) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Dancer to $label (${widget.danceName})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  // Fetch both members and competencies at the same time
                  future: Future.wait([
                    _teamRepository.fetchTeamMembers(),
                    _teamRepository.fetchCompetenciesForDance(widget.danceName),
                  ]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final results = snapshot.data ?? [];
                    final members = results[0] as List<TeamMember>;
                    final competencies = results[1] as List<Competency>;

                    // Create a quick lookup map for member competencies
                    // Key: memberId, Value: proficiencyLevel ('L', 'Q', or 'M')
                    final Map<String, String> competencyMap = {
                      for (var c in competencies)
                        c.memberId: c.proficiencyLevel,
                    };

                    if (members.isEmpty) {
                      return const Center(
                        child: Text('No team members found in database.'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final proficiency = competencyMap[member.id];
                        final isQualified =
                            proficiency == 'L' || proficiency == 'Q';

                        return ListTile(
                          leading: Icon(
                            isQualified ? Icons.star : Icons.star_border,
                            color: isQualified ? Colors.amber : Colors.grey,
                          ),
                          title: Text(member.fullName),
                          subtitle: Text(
                            isQualified
                                ? 'Qualified Level: $proficiency'
                                : 'Not Qualified for this dance',
                            style: TextStyle(
                              color: isQualified
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              fontWeight: isQualified
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() {
                              _assignedDancers[positionKey] = member.fullName;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
