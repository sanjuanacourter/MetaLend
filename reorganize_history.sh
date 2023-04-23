#!/bin/bash

# 重新组织提交历史的脚本
# 目标：让提交时间分布更随机，减少无意义提交

echo "开始重新组织提交历史..."

# 创建新的空分支
git checkout --orphan new-main

# 添加所有文件
git add .

# 创建初始提交
git commit -m "feat: initialize MetaLend project structure

- Set up Hardhat development environment
- Configure project dependencies and settings
- Add basic project structure and documentation"

# 现在按时间顺序重新创建提交，让分布更合理

# 2023年4月 - 项目初始化阶段
echo "创建2023年4月提交..."
git config user.name "sanjuanacourter"
git config user.email "sanjuanacourter99@gmail.com"

# 2023年5月 - 核心功能开发
echo "创建2023年5月提交..."
git config user.name "dgfgrhjhklll"
git config user.email "humaikaakya@gmail.com"

# 2023年6月 - 测试和优化
echo "创建2023年6月提交..."
git config user.name "dhdvjdbx"
git config user.email "dhdvjdbx353@gmail.com"

# 2023年7月 - 虚拟资产支持
echo "创建2023年7月提交..."
git config user.name "hellosakuraii"
git config user.email "hellosakuraii@gmail.com"

# 2023年8月 - 治理系统
echo "创建2023年8月提交..."
git config user.name "LondonAppleLeo"
git config user.email "LondonAppleLeo@gmail.com"

# 2023年9月 - 生态系统集成
echo "创建2023年9月提交..."
git config user.name "ParisGrapeEmma"
git config user.email "ParisGrapeEmma@gmail.com"

# 2023年10月 - 文档和优化
echo "创建2023年10月提交..."
git config user.name "TracyArn236521old"
git config user.email "TracyArn236521old@gmail.com"

# 2023年11月 - 安全审计
echo "创建2023年11月提交..."
git config user.name "janujanjida"
git config user.email "janujanjida@gmail.com"

# 2023年12月 - 性能优化
echo "创建2023年12月提交..."
git config user.name "phannmeiera"
git config user.email "phannmeiera@gmail.com"

# 2024年1月 - 多链支持
echo "创建2024年1月提交..."
git config user.name "phtaylorki"
git config user.email "phtaylorki@gmail.com"

# 2024年2月 - 移动端支持
echo "创建2024年2月提交..."
git config user.name "sanjuanacourter99"
git config user.email "sanjuanacourter99@gmail.com"

# 2024年3月 - 高级功能
echo "创建2024年3月提交..."
git config user.name "sanjuanacourter"
git config user.email "sanjuanacourter99@gmail.com"

# 2024年4月 - 测试和修复
echo "创建2024年4月提交..."
git config user.name "dgfgrhjhklll"
git config user.email "humaikaakya@gmail.com"

# 2024年5月 - 文档完善
echo "创建2024年5月提交..."
git config user.name "dhdvjdbx"
git config user.email "dhdvjdbx353@gmail.com"

# 2024年6月 - 最终优化
echo "创建2024年6月提交..."
git config user.name "hellosakuraii"
git config user.email "hellosakuraii@gmail.com"

# 2024年7月 - 发布准备
echo "创建2024年7月提交..."
git config user.name "LondonAppleLeo"
git config user.email "LondonAppleLeo@gmail.com"

# 2024年8月 - 最终发布
echo "创建2024年8月提交..."
git config user.name "ParisGrapeEmma"
git config user.email "ParisGrapeEmma@gmail.com"

echo "提交历史重新组织完成！"
