我希望系统了解bandit静态分析工具的功能、原理、cli使用。
我提供如下基础资源：https://bandit.readthedocs.io/en/latest/（官方文档）。

有一个额外需求：在/home/nyn/Desktop/Projects/SAST/SASTBenchmark/src/rulebench目录中，对于bandit有一套运行、结果处理逻辑。请仔细说明其流程，将其逻辑、指令、参数映射到官方文档的说明上。假设一个场景：需要对于Java、Go、PHP、Python、JS五种语言的开源项目进行扫描，需要产出<项目，rule，文件，行号>的扫描结果四元组。对于真实开源项目，Rulebench的处理逻辑是否适用（运行指令是否正确、结果处理逻辑是否适用？）？比如，是否需要编译项目、对于多语言项目的处理是否有语言适配问题、对于大型项目处理是否有运行时稳定性与性能问题、输出结果是否可定位告警的rule与告警的文件位置（可能的问题不止这几个，请你充分brainstorm）

请在/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/SAST-usage-learning目录下生成学习笔记，并按要求进行多轮扩充与解释润色，直到“只看你给出的学习笔记，非科班也能轻松了解bandit的作用、原理、使用方法，以及当前rulebench对bandit的运行与结果分析处理逻辑，并明确当前rulebench的处理逻辑对于真实项目是否适用”