import 'package:flutter_test/flutter_test.dart';
import 'package:foodvision/features/results/consensus_provider.dart';

void main() {
  group('ConsensusState Permission & Display', () {
    test('defaults to hasPermission: false and unreachable', () {
      const state = ConsensusState();
      expect(state.hasPermission, isFalse);
      expect(state.isReachable, isFalse);
      expect(state.hostDisplay, equals('Local Agent'));
    });

    test('updates hasPermission and hostDisplay via copyWith', () {
      const state = ConsensusState();
      final updated = state.copyWith(
        hasPermission: true,
        configuredUrl: 'http://192.168.0.200:11434',
        isReachable: true,
      );

      expect(updated.hasPermission, isTrue);
      expect(updated.isReachable, isTrue);
      expect(updated.hostDisplay, equals('192.168.0.200:11434'));
    });

    test('extracts hostname without default port when appropriate', () {
      const state = ConsensusState(configuredUrl: 'http://my-ollama.lan');
      expect(state.hostDisplay, equals('my-ollama.lan'));
    });
  });
}
