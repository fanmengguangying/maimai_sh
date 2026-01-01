#!/usr/bin/env python3
import http.server
import socketserver
import ssl
import random
import json
from datetime import datetime
import threading
import socket
import time

class PersistentSiliconFlowHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    
    def __init__(self, *args, **kwargs):
        self.request_count = 0
        super().__init__(*args, **kwargs)
    
    def handle(self):
        """重写handle方法以支持持久连接"""
        self.close_connection = False
        self.request_count = 0
        
        while not self.close_connection:
            try:
                # 设置超时，防止无限等待
                self.connection.settimeout(10.0)
                self.handle_one_request()
                self.request_count += 1
                # 模拟服务器主动关闭连接：每处理5个请求后关闭
                if self.request_count >= 5:
                    self.close_connection = True
                    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 主动关闭连接，已处理 {self.request_count} 个请求")
            except (ConnectionResetError, BrokenPipeError, socket.timeout) as e:
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 连接异常: {e}")
                self.close_connection = True
            except Exception as e:
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 处理请求时出错: {e}")
                self.close_connection = True
    
    def do_POST(self):
        if self.path == '/v1/chat/completions':
            # 随机选择状态码
            status_codes = [
                (503, "Service Unavailable", "server_error"),
                (429, "Rate limit exceeded", "rate_limit_error"), 
                (400, "Bad Request", "invalid_request_error"),
                (200, "OK", "success")
            ]
            status_code, message, error_type = random.choice(status_codes)
            
            # 构建响应体
            if status_code == 200:
                response_data = {
                    "id": f"chatcmpl-{random.randint(1000, 9999)}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": "silicon-flow-model",
                    "choices": [{
                        "index": 0,
                        "message": {"role": "assistant", "content": "这是一个模拟的成功响应"},
                        "finish_reason": "stop"
                    }]
                }
            else:
                response_data = {
                    "error": {
                        "message": message,
                        "type": error_type,
                        "code": status_code
                    }
                }
            
            response_body = json.dumps(response_data, ensure_ascii=False).encode('utf-8')
            
            # 设置响应头 - 必须设置Content-Length
            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(response_body)))
            self.send_header('Connection', 'keep-alive')
            self.send_header('Keep-Alive', 'timeout=60, max=100')
            
            if status_code == 429:
                self.send_header('Retry-After', '60')
            
            self.end_headers()
            
            # 写入响应体并刷新
            try:
                self.wfile.write(response_body)
                self.wfile.flush()  # 重要：确保数据被发送
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 响应发送完成 - 状态码: {status_code}, 内容长度: {len(response_body)}")
            except (BrokenPipeError, ConnectionResetError) as e:
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 写入响应时连接已关闭: {e}")
            
            # 记录日志
            client_ip = self.client_address[0]
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {client_ip} - 请求#{self.request_count} - 状态码: {status_code}")
            
        else:
            # 404 for other paths
            response_data = {"error": {"message": "Not Found", "code": 404}}
            response_body = json.dumps(response_data).encode('utf-8')
            
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_body)))
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            
            try:
                self.wfile.write(response_body)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {self.client_address[0]} - 请求#{self.request_count} - 状态码: 404")
    
    def do_GET(self):
        if self.path == '/health':
            response_data = {"status": "healthy", "timestamp": datetime.now().isoformat()}
            response_body = json.dumps(response_data).encode('utf-8')
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_body)))
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            
            try:
                self.wfile.write(response_body)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.do_POST()
    
    def log_message(self, format, *args):
        """自定义日志格式，减少冗余输出"""
        pass

class ThreadingHTTPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True
    
    def __init__(self, server_address, RequestHandlerClass):
        super().__init__(server_address, RequestHandlerClass)
        self.socket.settimeout(60)

def start_http_server(port=8080):
    with ThreadingHTTPServer(("", port), PersistentSiliconFlowHandler) as httpd:
        httpd.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        print(f"HTTP 服务运行在端口 {port}")
        httpd.serve_forever()

def start_https_server(port=8443):
    with ThreadingHTTPServer(("", port), PersistentSiliconFlowHandler) as httpd:
        # 设置 SSL 上下文
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain('cert.pem', 'key.pem')
        context.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1
        context.set_ciphers('ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS')
        
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        httpd.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        print(f"HTTPS 服务运行在端口 {port}")
        httpd.serve_forever()

def generate_self_signed_cert():
    """生成自签名证书"""
    import subprocess
    import os
    
    if not os.path.exists('cert.pem') or not os.path.exists('key.pem'):
        print("生成自签名证书...")
        try:
            subprocess.run([
                'openssl', 'req', '-x509', '-newkey', 'rsa:2048', 
                '-nodes', '-out', 'cert.pem', '-keyout', 'key.pem',
                '-days', '365', 
                '-subj', '/C=CN/ST=Beijing/L=Beijing/O=SiliconFlow/CN=localhost'
            ], check=True, capture_output=True)
            print("证书生成完成")
        except subprocess.CalledProcessError as e:
            print(f"证书生成失败: {e}")
            return False
    return True

if __name__ == '__main__':
    print("启动 SiliconFlow 双协议模拟服务（修复版）")
    print("HTTP 地址: http://localhost:8080/v1/chat/completions")
    print("HTTPS 地址: https://localhost:8443/v1/chat/completions")
    print("-" * 60)
    
    if not generate_self_signed_cert():
        print("无法生成证书，HTTPS服务可能无法启动")
    
    # 启动 HTTP 和 HTTPS 服务器
    http_thread = threading.Thread(target=start_http_server, args=(8080,))
    https_thread = threading.Thread(target=start_https_server, args=(8443,))
    
    http_thread.daemon = True
    https_thread.daemon = True
    
    http_thread.start()
    https_thread.start()
    
    print("服务器已启动，按 Ctrl+C 停止")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n正在停止服务器...")