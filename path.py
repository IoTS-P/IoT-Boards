import os 

def path_print(paths, depth, now_dir):
    header_ = ""
    for i in range(depth):
        header_ += "    "
    header_ += "* "
    for (k,v) in paths.items():
        next_dir = f"{now_dir}{k}/"
        print(f"{header_} [{k}]({next_dir})")
        path_print(v, depth+1, next_dir)
        

paths = {}
for root, dirs, files in os.walk('./'):
    for file in files:
        if file != 'README.md':
            continue
        s_ = root.split('/')
        temp = paths
        for d in s_:
            if temp.get(d) is None:
                temp[d] = {}
            temp = temp[d]
        temp = file 
path_print(paths['.'], 0, '')
