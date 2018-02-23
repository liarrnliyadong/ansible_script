#!/bin/bash
#将原有的一块硬盘，增加硬盘大小扩容
#用法./lvm.sh 100 50  其中100为目的大小，50为原大小

#列出所有扫描出的硬盘结尾字母
echo "">m.txt
#i：数组序列号
i=0 
for string in `cat /proc/partitions | grep sd | awk -F ' ' '{print $4}'`
#string：sda sda1 sda2 sdb sdc...
do
#${deviceTag[@]}：a a a 
deviceTag[${i}]=${string:2:1}
echo ${deviceTag[${i}]} >>m.txt
let i=${i}+1
done
#去重后 n.txt内容 a 
grep -v '^$' m.txt > n.txt
diskEnd=`sort -u n.txt` 
diskName=/dev/sd$diskEnd
#调试信息diskName=/dev/sda
#echo "diskEnd=$diskEnd"
#echo "diskName=$diskName"

#dest_mem增加后硬盘大小，需手动输入
#source_mem增加前硬盘大小，需手动输入
dest_mem=$1
#echo "diskName=$diskName"
source_mem=$2
#echo "source_mem=$source_mem"
#如无特殊情况，fist_sector为新建device的第一个地址
fist_sector=`echo "1024*1024*$source_mem" | bc -l`
#echo "fist_sector=$fist_sector"

#安装partprobe expect
sudo apt-get update
sudo apt-get install parted expect -y

#列出所有扫描出的硬盘结尾数字
echo "">1.txt
#i：数组序列号
i=0 
for string in `cat /proc/partitions | grep sd | awk -F ' ' '{print $4}'`
#string：sda sda1 sda2 
do
deviceTag[${i}]=${string:3:1}
#${deviceTag[@]}：1 2 5  ...
#1.txt：1 2 5  ...
echo ${deviceTag[${i}]} >>1.txt
let i=${i}+1
done

#新建device
echo "spawn sudo fdisk /dev/sda
 expect {
 "Be\\ careful\\ before\\ using\\ the\\ write\\ command" {send "n\\r"; exp_continue}
 "Select\\ " { send "p\\r"; exp_continue}
 "Partition\\ number" { send "\\r"; exp_continue}
 "499712" { send "$fist_sector\\r"; exp_continue}
"Value\\ out\\ of\\ range" { send "\\r"; exp_continue}
"already\\ allocated" { send "\\r"; exp_continue}
 "Last" { send "\\r"; exp_continue}
 "Created\\ a\\ new\\ partition" { send "w\\r"; exp_continue}
 }
 expect eof" > lvm.txt
expect -f lvm.txt
sudo partprobe

#列出所有扫描出的硬盘结尾数字
echo "">2.txt
#i：数组序列号
i=0 
for string in `cat /proc/partitions | grep sd | awk -F ' ' '{print $4}'`
#string：sda sda1 sda2 sda3 ... 
do
deviceTag[${i}]=${string:3:1}
#${deviceTag[@]}：1 2 3 5  ...
#2.txt：1 2 3 5  ...
echo ${deviceTag[${i}]} >>2.txt
let i=${i}+1
done

#num新增的device数字
num=`diff 1.txt 2.txt | grep ">" | awk -F '' '{print $3}'`

#将新建的linux device修改为lvm
echo "spawn sudo fdisk /dev/sda
 expect {
 "Be\\ careful\\ before\\ using\\ the\\ write\\ command" {send "t\\r"; exp_continue}
 "Partition\\ number" { send "$num\\r"; exp_continue}
"Hex\\ code" { send "8e\\r"; exp_continue}
"Changed\\ type\\ of\\ partition" { send "w\\r"; exp_continue}
 }
 expect eof" > lvm0.txt
expect -f lvm0.txt

sudo partprobe

#lvm扩容
#创建pv
disk=$diskName$num
sudo pvcreate $disk
vgName=`vgdisplay | grep VG\ Name | awk -F ' ' '{print $3}'`
echo "vgName=$vgName"
#vg扩容
sudo vgextend $vgName $disk
lvList=`lvdisplay | grep LV\ Name | awk -F ' ' '{print $3}'`
lvName=`echo "$lvList" | sed '/swap*/d'`

echo "lvName=$lvName"
#lv扩容，大小为硬盘大小
operator="+"
unit="G"
extend_mem=`echo "$dest_mem-$source_mem" | bc -l`
extend_operation=$operator$extend_mem$unit
sudo lvextend -L $extend_operation /dev/$vgName/$lvName
#文件系统resize
sudo resize2fs /dev/$vgName/$lvName

rm  *.txt
