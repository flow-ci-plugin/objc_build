
# objc_build Step
Objc build task

### INPUTS
* `FLOW_IOS_COMPILE_WORKSPACE` - 
* `FLOW_IOS_COMPILE_PROJECT` - 
* `FLOW_IOS_COMPILE_SCHEME` - 
* `FLOW_IOS_COMPILE_CONFIGURATION` - 

## EXAMPLE 

```yml
steps:
  - name: objc_build
    enable: true
    failure: true
    plugin:
      name: objc_build
      inputs:
        - FLOW_IOS_COMPILE_WORKSPACE=$FLOW_IOS_COMPILE_WORKSPACE
        - FLOW_IOS_COMPILE_PROJECT=$FLOW_IOS_COMPILE_PROJECT
        - FLOW_IOS_COMPILE_SCHEME=$FLOW_IOS_COMPILE_SCHEME
        - FLOW_IOS_COMPILE_CONFIGURATION=$FLOW_IOS_COMPILE_CONFIGURATION
```
