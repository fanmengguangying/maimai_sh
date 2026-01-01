# 1. 切换到主分支
git checkout main  # 或 master

# 2. 创建新的孤儿分支（无历史）
git checkout --orphan latest_branch

# 3. 添加所有文件到新分支
git add -A

# 4. 提交初始提交
git commit -m "Initial commit"

# 5. 删除旧的主分支
git branch -D main  # 或 master

# 6. 重命名当前分支为主分支
git branch -m main  # 或 master

# 7. 强制推送到远程仓库
git push -f origin main
