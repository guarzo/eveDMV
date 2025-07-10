%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/",
          ~r"/assets/",
          ~r"/priv/static/",
          ~r"/test/manual/"
        ]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          ## Consistency Checks
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          ## Design Checks
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagTODO, [exit_status: 2]},
          {Credo.Check.Design.TagFIXME, []},
          # Enhanced: Additional design checks available in Credo
          {Credo.Check.Design.SkipTestWithoutComment, []},

          ## Readability Checks
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          # Enhanced: Strict moduledoc enforcement with specific exclusions
          {Credo.Check.Readability.ModuleDoc,
           [
             ignore_names: [
               ~r/.*Test$/,
               ~r/.*TestCase$/,
               ~r/.*Factory$/,
               ~r/.*Mock$/,
               ~r/.*Fixture$/,
               ~r/.*DataCase$/,
               ~r/.*ConnCase$/,
               ~r/.*ChannelCase$/,
               ~r/.*Support\./,
               ~r/.*Gettext$/,
               ~r/.*Endpoint$/,
               ~r/.*Router$/,
               ~r/.*Telemetry$/,
               ~r/.*Application$/
             ]
           ]},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},
          # Enhanced: Additional readability checks
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, [min_pipeline_length: 3]},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.StrictModuleLayout,
           [
             order: [
               :moduledoc,
               :shortdoc,
               :behaviour,
               :use,
               :import,
               :alias,
               :require,
               :defstruct,
               :module_attribute,
               :opaque,
               :type,
               :typep,
               :callback,
               :macrocallback,
               :optional_callbacks,
               :defmacro,
               :defguard,
               :defguardp,
               :def,
               :defp,
               :defmacrop,
               :defoverridable,
               :defimpl,
               :defprotocol,
               :defdelegate
             ]
           ]},

          ## Refactoring Opportunities
          {Credo.Check.Refactor.CondStatements, []},
          # Enhanced: Stricter complexity limits for better code quality
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 10]},
          {Credo.Check.Refactor.FunctionArity, [max_arity: 6]},
          {Credo.Check.Refactor.LongQuoteBlocks, [max_line_count: 60]},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},
          # Enhanced: Additional refactoring checks
          {Credo.Check.Refactor.ABCSize, [max_size: 35]},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, [max_deps: 15]},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.VariableRebinding, []},

          ## Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MixEnv, false},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.UnsafeExec, []},
          # Enhanced: Additional warning checks
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.UnsafeToAtom, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.ForbiddenModule, []},

          ## Custom checks for EVE DMV specific requirements
          {Credo.Check.Design.DuplicatedCode,
           [
             # Allow more duplication due to data processing patterns
             mass_threshold: 35,
             nodes_threshold: 3
           ]}
        ],
        disabled: [
          # Some warnings we want to allow for specific use cases
          {Credo.Check.Warning.LazyLogging, []},
          # Allow MapInto for performance reasons in data processing
          {Credo.Check.Refactor.MapInto, []},
          # Allow anonymous function in pipes for data transformation
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          # Temporarily disabled until we can refactor large functions
          {Credo.Check.Refactor.ABCSize, []},
          # Allow some complexity in analysis modules temporarily
          {Credo.Check.Refactor.CyclomaticComplexity, []}
        ]
      }
    }
  ]
}
