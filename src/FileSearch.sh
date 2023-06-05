#! /bin/bash
read -t 20 -p "Please enter the folder you want to search :" folderName
read -t 20 -p "Please enter your search content :" content  
retrieveFiles (){
	for fileName in $(ls -r $1)
	do
		#目录路径加上要检索的文件或目录
		local localFileName=$1/$fileName
		#如果是目录继续递归查看里面的文件
		if [ -d $localFileName ]
		then
			retrieveFiles $localFileName $2
		else
			grep "$2" $localFileName >> temp.txt && echo $localFileName
		fi
	done
}

retrieveFiles $folderName $content
