import socket, threading, time, json

def packet(c):
    header = c.recv(1)
    if not header: return None, None
    n = 0; shift = 0
    while True:
        b = c.recv(1)[0]; n |= (b & 127) << shift
        if b < 128: break
        shift += 7
    data = b''
    while len(data) < n:
        part = c.recv(n-len(data))
        if not part: raise EOFError()
        data += part
    return header[0], data

def session(c, index):
    try:
        packet(c)
        if index == 8: time.sleep(.5)
        if index == 9:
            c.sendall(b'\x20\x02\x00\x05'); return
        c.sendall(b'\x20\x02\x00\x00')
        while True:
            h, d = packet(c)
            if h is None or h >> 4 == 14: break
            if h >> 4 == 8:
                if index == 10: return
                c.sendall(b'\x90\x03' + d[:2] + (b'\x80' if index == 10 else b'\x01'))
                if index != 10:
                    topic = ('broker/%d' % index).encode()
                    body = bytes([0,len(topic)]) + topic + b'fixture'
                    c.sendall(bytes([0x31,len(body)]) + body)
                    if index == 7:
                        time.sleep(.3); return
            if h >> 4 == 12: c.sendall(b'\xd0\x00')
    except (OSError, EOFError, IndexError): pass
    finally: c.close()

def accept(s, i):
    while True:
        c,_=s.accept(); threading.Thread(target=session,args=(c,i),daemon=True).start()

sockets=[]
for i in range(11):
    s=socket.socket(); s.bind(('127.0.0.1',0)); s.listen(); sockets.append(s)
    threading.Thread(target=accept,args=(s,i),daemon=True).start()
print(json.dumps([s.getsockname()[1] for s in sockets]),flush=True)
threading.Event().wait()
