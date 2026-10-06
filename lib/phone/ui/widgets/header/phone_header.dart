import 'package:flutter/material.dart';

import 'connection_pill.dart';
import 'live_badge.dart';
import 'pc_sync_chip.dart';
import 'sleep_button.dart';

/// Top bar: PC link and live state, then connection details and screen-off.
class PhoneHeader extends StatelessWidget {
  const PhoneHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          PcSyncChip(),
          Spacer(),
          LiveBadge(),
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: ConnectionPill()),
          SizedBox(width: 10),
          SleepButton(),
        ]),
      ]),
    );
  }
}
