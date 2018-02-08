# nfs_config.py
# Author: Walle (chenweiqi@cvte.com)
# Date: 2018/2/7:23:10:42
# Description: Execute this script on server, to config folders for NFS.
# Modify: 

import sys, string, os
import os.path
import commands
import shutil

DEFAULT_IMAGE_DIR = "/home/chenweiqi/6586/5_6586_ISDB/Supernova/target/isdb.macan/tmp_image/"

DEFAULT_NFS_FILE_DIR = "/home/chenweiqi/nfs"

DEFAULT_SUB_DIR=[
		"mslib", 
		"applications"
]
nfs_service_name="nfs-kernel-server"

class NfsConfig:
	def InitNfsFile(self, exports_dir):
		if os.path.exists(exports_dir) is not True:
			os.mkdir(exports_dir)		

	def CheckNfsService(self, service_name):
		service_status_str=commands.getoutput("service "+service_name+" status")
		service_status=string.split(service_status_str)[1]
		print("Service NFS "+service_status);	
		if(service_status == "running"):
			return True
		else:
			return False

class FileConfig:
	def UpdateAllFile(self, tmp_image_dir, destination_dir):	
		if os.path.exists(tmp_image_dir) is not True:
			print(tmp_image_dir + " path is not exists!")
			return False;
	
		for sub_path in self.folder_list:
			source_dir = tmp_image_dir+'/'+sub_path	
			dest_dir = destination_dir+'/'+sub_path
			#clear old folder
			if os.path.exists(dest_dir):
				shutil.rmtree(dest_dir)
			
			shutil.copytree(source_dir, dest_dir, True)

	def SetSubFolderList(self, sub_folder):
		self.folder_list = sub_folder

class Customize:
	def ShowUsageAndExit(self):
		print("");
		print("Usage: python nfs_config.py <image_path>|<--d> [nfs_file_path] [sub_folder1,sub_folder2,...]")
		sys.exit();

	def CustomizePara1(self, argv):
		if argv[1] == "--d":
			self.DoConfig(DEFAULT_IMAGE_DIR, DEFAULT_NFS_FILE_DIR, DEFAULT_SUB_DIR)
		else:
			self.DoConfig(argv[1], DEFAULT_NFS_FILE_DIR, DEFAULT_SUB_DIR);
	
	def CustomizePara2(self, argv):
		self.DoConfig(argv[1], argv[2], DEFAULT_SUB_DIR);

	def CustomizePara3(self, argv):
		self.DoConfig(argv[1], argv[2], argv[3].split(','))
		

	def DoConfig(self, image_dir, nfs_file_dir, sub_dirs):
		nfs_config = NfsConfig()
		file_config = FileConfig()
	
		if nfs_config.CheckNfsService(nfs_service_name) is not True:
			print("NFS is not running, failure ")
			quit();
	
		nfs_config.InitNfsFile(nfs_file_dir)
		print("Update folders: " + str(sub_dirs))
		file_config.SetSubFolderList(sub_dirs)
		file_config.UpdateAllFile(image_dir, nfs_file_dir)

	CustomizeMap={1: ShowUsageAndExit,
					2: CustomizePara1,
					3: CustomizePara2,
					4: CustomizePara3}

def main(argv):
	argv_len = len(argv)
	customize = Customize()	
	try:
		customize.CustomizeMap[argv_len](customize, argv)
	except :
		info=sys.exc_info()
		print("")
		print(info[1])
		customize.ShowUsageAndExit()

if __name__ == "__main__":
	main(sys.argv)
