# GenQuery Development Decisions
## Date: December 6, 2025

This document captures key architectural and development process decisions made to improve GenQuery development efficiency.

## Decision Framework
- Priority 1: Get to beta quickly with core functionality working
- Priority 2: Reduce development friction and debugging time  
- Priority 3: Improve user experience for initial setup
- Priority 4: Maintain extensibility for future growth

---

## Key Recommendations for Discussion

### 1. Simplify Radically
**Recommendation**: Replace interactive config wizard with simple init command
**Status**: REVISED - Keep user-facing interactivity, simplify developer tools
**Decision**: 
- KEEP interactive wizards for end users (genealogy researchers who prefer guided experiences)
- Tab completion and drill-down navigation are critical for non-technical users
- Create separate developer-only commands for testing and validation
- User experience takes priority over code simplicity
**Revised Approach**:
- User commands: `genq config` remains interactive with tab completion
- Dev commands: `genq dev validate`, `genq dev test`, `genq dev deploy`
- Separation allows complex user UX while maintaining developer efficiency
**Implementation**:
- Add `$env.GENQ_DEV_MODE = true` to env.nu during development
- Developer commands only visible when flag is set
- End users never see dev commands in tab completion or help
- Clean separation of concerns

### 2. Test Early and Often  
**Recommendation**: Create validation scripts that run before deployment
**Status**: APPROVED - Comprehensive regression testing framework
**Decision**:
- Create `genq dev validate` as complete regression test suite
- Test all functionality, not just syntax
- Visual output: ✅ (passed) and ❌ (failed) with descriptions
- Log results to file for analysis and analytics
- Use for cross-platform testing (Windows/macOS)
- Test with multiple RootsMagic database versions
**Implementation**:
- Display: Simple one-line per test with colored status symbols
- Logging: Detailed results to `logs/validate-YYYY-MM-DD-HHmm.log`
- Categories: Syntax, Core Commands, Extensions, Database Compatibility
- Analytics: Log files become source for quality metrics
**Example Output**:
```
GenQuery Validation Suite v1.0
Testing with database: pres2020.rmtree

SYNTAX CHECKS:
✅ main.nu syntax valid
✅ common modules syntax valid
✅ extension modules syntax valid

CORE COMMANDS:
✅ genq help displays correctly
✅ genq list people returns data
❌ genq assess consistency - NOT IMPLEMENTED
✅ genq config shows settings

Results: 18/20 passed
Full log: logs/validate-2025-06-12-1430.log
```

### 3. Document Gotchas
**Recommendation**: Maintain pattern library for common Nushell issues
**Status**: APPROVED - Created nushell-gotchas.md
**Decision**:
- Created separate nushell-gotchas.md for Nushell-specific patterns
- Formatted for easy AI processing with clear problem/solution structure
- Extracted all Nushell quirks from lessons-learned.md
- lessons-learned.md now focuses on high-level insights
**Implementation**:
- nushell-gotchas.md: Technical reference with code examples
- Each gotcha includes: Problem, Incorrect Pattern, Correct Pattern, Rule
- lessons-learned.md: Strategic insights updated before commits
- Clear separation of tactical (gotchas) vs strategic (lessons) documentation

### 4. Static Over Dynamic
**Recommendation**: Use explicit paths and imports instead of discovery
**Status**: KEEP DYNAMIC - For extension discovery only
**Decision**:
- Keep dynamic extension discovery for developer convenience
- Extension developers can "just drop in" new extensions without modifying core
- This encourages community contributions and custom extensions
- Use static/environment paths for everything else (config, databases, etc.)
**Implementation**:
- Extensions: Keep scanning src/lib/ext/ dynamically
- Core paths: Use environment variables (GENQ_HOME, etc.)
- Config files: Use known locations with environment variable base
- Balance: Dynamic where it helps developers, static where it adds stability

### 5. Focus on Critical Path
**Recommendation**: Get basic functionality working before complex features  
**Status**: POSTPONED - To be determined with beta tester input
**Decision**:
- Postpone decision until beta testing phase
- "NOT FUNCTIONAL YET" commands are placeholders for future functionality
- Will solicit beta tester input on which reports deliver most value
- Focus on making existing commands work perfectly rather than adding new ones
**Next Steps**:
- Get current functionality stable and tested
- Launch beta with existing features
- Gather feedback on what reports/assessments users actually want
- Implement based on real user needs rather than assumptions

---

## Implementation Priority Order

Based on our decisions, here's the recommended implementation order:

### Phase 1: Developer Infrastructure (1-2 days)
1. **Add developer mode flag** to env.nu (`$env.GENQ_DEV_MODE = true`)
2. **Create `genq dev validate`** - Comprehensive regression testing
3. **Create `genq dev test`** - Test individual functions
4. **Create `genq dev deploy`** - Validate and deploy to autoload

### Phase 2: Documentation (0.5 days)
1. **Maintain nushell-gotchas.md** - Already created, keep updating
2. **Update lessons-learned.md** - Before each major commit

### Phase 3: Fix Current Issues (2-3 days)
1. **Fix working directory issues** in autoload context
2. **Complete config system** - Make existing commands work properly
3. **Test all existing commands** with new validation framework
4. **Fix any broken extension commands**

### Phase 4: Beta Preparation (1-2 days)
1. **Remove or hide** "NOT FUNCTIONAL YET" commands
2. **Polish user experience** for core commands
3. **Create simple getting-started guide**
4. **Test on Windows and macOS** with fresh installs

### Phase 5: Beta Launch
1. **Deploy to beta testers**
2. **Gather feedback** on desired reports/assessments
3. **Iterate based on real user needs**

**Total Estimated Time**: 5-8 days to beta-ready state

## Key Principles Going Forward
1. **User experience first** - Optimize for genealogy researchers, not developers
2. **Test everything** - Use new validation framework before every deployment
3. **Document patterns** - Update nushell-gotchas.md when new issues found
4. **Real feedback** - Let beta users drive feature priorities
5. **Stability over features** - Make existing commands rock-solid