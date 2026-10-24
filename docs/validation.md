# Compute collection validation

The CI matrix runs all ten service folders. Each job performs shared Python tests, PowerShell syntax parsing, recursive Terraform formatting, provider validation for its module and two environment roots, module mock plans, and the PowerShell validate entry point against both roots. Dependency versions and lock files are committed.

The Windows implementation initially passed 18 Python and four Terraform tests before the collection refactor; that baseline run is [40060736344](https://github.com/dotman01k/azure-automated-pipeline/actions/runs/40060736344). Use the latest matrix run for the new folder layout and additional services. Earlier deployment history is not evidence for this newly authored collection.

Local Python, input, link and formatting checks are recorded during preparation. Provider plugin execution is restricted in the preparation runtime; hosted CI is the authority for provider validation/mock plans. A pass does not establish Azure DevOps server-side template expansion, service availability, capacity, authentication, application deployment, AVD session registration/login, Batch task execution or Service Fabric management/application behavior. Record those separately in a live acceptance run without publishing secrets or state.
