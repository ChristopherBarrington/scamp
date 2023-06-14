name: a readable name

description: |
  A short description of the module's function.

tags:
  - lowercase
  - strings

steps:
  - name: a name of the step
    description: a short description of what this step does
    anchor: line number of main.nf to link
    parameters:
      - key: name of parameters key sought
        description: Short description of what this parameter is used for
        type: expected type
    modules:
      - a collection of modules using path under `modules`
      - eg cell_ranger/count

output:
  - name: result
    type: channel
    description: A channel of maps that are the same as the input parameters sets but now include `index path` _and_ `quantification path` parameters.

authors:
  - "@ChristopherBarrington"
