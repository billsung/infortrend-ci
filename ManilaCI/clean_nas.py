
from manila.share.drivers.infortrend import infortrend_nas


class NAS_CMD(infortrend_nas.InfortrendNAS):

    def __init__(self, *args, **kwargs):
        kargs = {
            "nas_ip": nas_ip,
            "username": username,
            "password": password,
            "ssh_key": ssh_key,
            "retries": retries,
            "timeout": timeout,
            "pool_dict": pool_dict,
            "channel_dict": channel_dict
        }
        super(NAS_CMD, self).__init__(**kargs)

    def delete_subfolders(self, pool_name):
        pool_id = self.pool_dict[pool_name]
        path = self.pool_dict[pool_name]['path']
        command_line = ['pagelist', 'folder', path]
        rc, subfolders = self._execute(command_line)
        for subfolder in subfolders:
            if(subfolder['name'] != 'UserHome'):
                print('Deleting %s ...' % subfolder['name'])
                command_line = ['folder', 'options', pool_id,
                                pool_name, '-d', subfolder['name']]
                self._execute(command_line)
        return


def _init_pool_dict(pool_list):
    temp_pool_dict = {}
    for pool in pool_list:
        temp_pool_dict[pool] = {}
    return temp_pool_dict


nas_ip = "172.27.114.66"
username = "manila"
password = "qwer1234"
retries = 3
timeout = 30
pool_list = ["InfortrendShare-1", "InfortrendShare-2"]
pool_dict = _init_pool_dict(pool_list)
ssh_key = None
channel_dict = {'0': '', '1': ''}


nas = NAS_CMD(nas_ip, username, password, ssh_key,
              retries, timeout, pool_dict, channel_dict)

nas.check_for_setup_error()
nas.delete_subfolders(pool_list[0])
nas.delete_subfolders(pool_list[1])
print("All Finished.")
