import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';
import '../widgets/brand_header.dart';
import '../widgets/connection_card.dart';
import '../widgets/error_text.dart';
import '../widgets/output_card.dart';
import '../widgets/phone_controls_panel.dart';
import '../widgets/preview_panel.dart';
import '../widgets/stats_bar.dart';
import '../widgets/virtual_camera_card.dart';

/// Desktop main window: settings on the left, preview in the middle, phone
/// camera controls on the right (or under the preview on narrow windows).
class DesktopHomeScreen extends StatelessWidget {
  const DesktopHomeScreen({super.key});

  static const _wideBreakpoint = 1180.0;

  @override
  Widget build(BuildContext context) {
    final phoneConnected = context.select<DesktopProvider, bool>((c) => c.phone != null);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > _wideBreakpoint;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 330,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  BrandHeader(),
                  SizedBox(height: 16),
                  ConnectionCard(),
                  SizedBox(height: 12),
                  VirtualCameraCard(),
                  SizedBox(height: 12),
                  OutputCard(),
                  ErrorText(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: Column(children: [
                  const Expanded(child: PreviewPanel()),
                  const SizedBox(height: 10),
                  const StatsBar(),
                  if (!wide && phoneConnected) ...[
                    const SizedBox(height: 10),
                    const SizedBox(height: 230, child: PhoneControlsPanel()),
                  ],
                ]),
              ),
            ),
            if (wide && phoneConnected)
              const SizedBox(
                width: 300,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: PhoneControlsPanel(),
                ),
              ),
          ],
        );
      }),
    );
  }
}
