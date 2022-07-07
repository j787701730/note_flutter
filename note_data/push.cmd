REM 声明采用UTF-8编码
chcp 65001
cd %~dp0
git pull
git add .
git commit -m 'commit'
git push origin master
@echo off
echo 提交成功
pause
exit