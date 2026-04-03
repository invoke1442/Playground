# Purpose
project-background-skill-creator旨在为特定项目中的不同任务，以统一的接口（Skill）提供背景资源。
以Skill形式（而不是静态资源）提供这些资源有如下优势：
- 逻辑组织：agent对于skill的文件结构有专门优化。可利用这一点，通过skills的文件结构（如references）组织各类资源，在文件结构中强调各类资源的逻辑联系。这样，agent可以更加深刻理解项目各个模块的联系。
- 动态渐进披露：对于不同任务，agent可以选择性披露不同资源，节约上下文。
- 可扩展性：
  - skill格式原生支持链接到其他skill，从而提供模块化的扩展性。可以用项目背景skill链接到其他更具体的下游技术skill，如不同SAST工具的skill。
  - skill的更新与优化可复用开源社区提供的meta-skills，如codex skill creator，skill testing等

# 说明
由于“为项目创建Skill”任务本身不需要动态渐进披露，因此不采用Skill形式。当前先用codex的skill creator工具 + 静态prompt 来直接创建不同项目的Skill。

