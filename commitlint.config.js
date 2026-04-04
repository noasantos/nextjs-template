module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // Type must be one of the following
    "type-enum": [
      2,
      "always",
      [
        "feat", // New feature
        "fix", // Bug fix
        "docs", // Documentation changes
        "style", // Code style changes (formatting, etc.)
        "refactor", // Code refactoring
        "perf", // Performance improvements
        "test", // Test changes
        "build", // Build system changes
        "ci", // CI/CD changes
        "chore", // Maintenance tasks
        "revert", // Revert previous commits
      ],
    ],

    // Subject cannot be sentence-case, start-case, pascal-case, or upper-case
    "subject-case": [2, "never", ["sentence-case", "start-case", "pascal-case", "upper-case"]],

    // Subject cannot be empty
    "subject-empty": [2, "never"],

    // Subject max length
    "subject-max-length": [2, "always", 100],

    // Type cannot be empty
    "type-empty": [2, "never"],

    // Type must be lowercase
    "type-case": [2, "always", "lower-case"],

    // Body max line length
    "body-max-line-length": [2, "always", 100],

    // Body must start with uppercase
    "body-leading-blank": [2, "always"],

    // Footer max line length
    "footer-max-line-length": [2, "always", 100],

    // Footer must start with uppercase
    "footer-leading-blank": [2, "always"],
  },
}
