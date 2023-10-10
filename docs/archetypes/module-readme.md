name: a readable name

description: |
  A short description of the module's function.

tags:
  - lowercase
  - strings

tools:
  name of software:
    description: A markdown-ready description - pillaged from its website!
    homepage: url, could be github
    documentation: maybe a readthedocs
    source: url to (eg) github
    doi: doi
    licence: eg MIT or GPL-3
    ext: extra arguments identifier
    features:
      - list of features

input:
  - name: opt
    type: map
    description: A map of task-specific variables.
  - name: tag
    type: string
    description: A unique identifier to use in the tag directive.

output:
  - name: opt
    type: map
    description: A map of task-specific variables.
  - name: task
    type: file
    description: YAML-formatted file of task parameters and software versions used by the process.
    pattern: task.yaml

authors:
  - "@ChristopherBarrington"
