## Description
Summary of the changes introduced in this Pull Request.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Hardware driver / Super I/O support expansion
- [ ] Documentation update
- [ ] Performance optimization

## Verification & Testing
Describe the tests you ran to verify your changes:
1. Ran `tests/Invoke-AetherTestSuite.ps1` (8/8 tests passed)
2. Verified zero memory leak (Delta RAM = 0 MB)
3. Verified sub-2ms polling latency
4. Verified Light and Dark mode rendering

## Safety Checklist
- [ ] Does not execute unauthorized external web requests.
- [ ] Preserves safety thermal override (`>85°C` triggers 100% cooling).
- [ ] Tested on Windows 10 / Windows 11.
