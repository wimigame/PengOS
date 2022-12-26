###########################################
## @Author: 陈小鹏
## @Date: 2022-12-26 16:24:22
## @LastEditors: Please set LastEditors
## @LastEditTime: 2022-12-26 16:37:45
## @FilePath: /peng/Makefile
###########################################

##定义工程目录 -- 顶级目录
SRoot = /Users/chenshipeng/Documents/project/system
export SRoot

模块 = 启动 \

目录 = $(模块)	\
	   构建镜像

include PengOS.mk

images: $(模块)
