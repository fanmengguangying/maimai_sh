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
import os

# 全局调试模式标志
DEBUG_MODE = os.environ.get('DEBUG', 'false').lower() == 'true'

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
        # 读取请求体
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b''
        
        # 调试模式：显示请求详情
        if DEBUG_MODE:
            self._log_request_details(body)
        
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
                
                if DEBUG_MODE:
                    self._log_response_details(status_code, response_body)
                else:
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
    
    def _log_request_details(self, body):
        """显示请求的详细信息"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        client_ip = self.client_address[0]
        
        print(f"\n{'='*70}")
        print(f"[{timestamp}] ===== 请求详情 (请求#{self.request_count}) =====")
        print(f"客户端: {client_ip}:{self.client_address[1]}")
        print(f"方法: {self.command}")
        print(f"路径: {self.path}")
        print(f"协议: {self.request_version}")
        
        # 显示请求头
        print(f"\n请求头:")
        for header, value in self.headers.items():
            print(f"  {header}: {value}")
        
        # 显示请求体
        if body:
            print(f"\n请求体:")
            try:
                request_json = json.loads(body.decode('utf-8'))
                print(json.dumps(request_json, indent=2, ensure_ascii=False))
            except (json.JSONDecodeError, UnicodeDecodeError):
                print(f"  {body[:200].decode('utf-8', errors='ignore')}...")
        else:
            print(f"\n请求体: 无")
        
        print(f"{'='*70}\n")
    
    def _log_response_details(self, status_code, response_body):
        """显示响应的详细信息"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        print(f"\n{'-'*70}")
        print(f"[{timestamp}] ===== 响应详情 =====")
        print(f"状态码: {status_code}")
        print(f"内容长度: {len(response_body)} 字节")
        
        print(f"\n响应体:")
        try:
            response_json = json.loads(response_body.decode('utf-8'))
            print(json.dumps(response_json, indent=2, ensure_ascii=False))
        except (json.JSONDecodeError, UnicodeDecodeError):
            print(f"  {response_body[:200].decode('utf-8', errors='ignore')}...")
        
        print(f"{'-'*70}\n")

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
    
    if DEBUG_MODE:
        print("✓ 调试模式已启用 - 将显示请求和响应的详细信息")
        print("提示: 设置 DEBUG=false 或删除环境变量可关闭调试模式")
    else:
        print("调试模式已禁用 - 仅显示基本日志")
        print("提示: 运行 'set DEBUG=true' 可启用调试模式")
    
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