## ADDED Requirements

### Requirement: KeyCat 光标方向一致
KeyCat SHALL 将屏幕坐标转换为网页左上角坐标，视线与轮廓命中均使用同一坐标系。

#### Scenario: 四方向跟随
- **WHEN** 光标在桌宠左、右、上、下移动
- **THEN** 桌宠视线分别朝屏幕左、右、上、下移动，不受窗口位置影响。

#### Scenario: 头部命中
- **WHEN** 鼠标位于 KeyCat 的头部
- **THEN** 命中检测按实际鼠标位置判定摸头区域，不发生上下镜像。
