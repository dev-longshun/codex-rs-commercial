package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

const managementUploadPageHTML = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>CLIProxyAPI - 拖拽上传认证文件</title>
  <style>
    :root { color-scheme: dark; }
    body { margin: 0; padding: 24px; font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background:#0f1115; color:#e8ecf3; }
    .wrap { max-width: 760px; margin: 0 auto; }
    h1 { margin: 0 0 8px; font-size: 24px; }
    p { margin: 0 0 16px; color:#a9b3c7; }
    .card { background:#161a22; border:1px solid #2a3344; border-radius:12px; padding:16px; margin-bottom:16px; }
    label { display:block; margin-bottom:8px; font-weight:600; }
    input[type="password"] { width:100%; box-sizing:border-box; padding:10px 12px; border-radius:8px; border:1px solid #324158; background:#0f141e; color:#e8ecf3; }
    .dropzone { border:2px dashed #3f4f6a; border-radius:12px; padding:28px 18px; text-align:center; background:#111825; cursor:pointer; transition:all .15s ease; }
    .dropzone.dragover { border-color:#7aa2ff; background:#182238; }
    .dropzone strong { font-size:16px; }
    .actions { display:flex; gap:12px; margin-top:14px; }
    button { border:0; border-radius:8px; padding:10px 14px; background:#2e6bff; color:#fff; font-weight:600; cursor:pointer; }
    button:disabled { opacity:.55; cursor:not-allowed; }
    .muted { color:#8f9bb3; font-size:12px; margin-top:8px; }
    .status { white-space:pre-wrap; margin-top:12px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background:#0e1320; border:1px solid #29354a; border-radius:8px; padding:12px; min-height:44px; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>认证文件拖拽上传</h1>
    <p>用于上传 OAuth 认证文件到当前服务（调用 <code>/v0/management/auth-files</code>）。</p>
    <div class="card">
      <label for="mgmtKey">管理密钥（remote-management.secret-key）</label>
      <input id="mgmtKey" type="password" placeholder="输入管理密钥" autocomplete="off" />
      <div class="muted">仅在本页用于请求头 <code>X-Management-Key</code>，不会写入服务端配置。</div>
    </div>
    <div class="card">
      <input id="fileInput" type="file" hidden />
      <div id="dropzone" class="dropzone">
        <strong>把认证文件拖到这里</strong><br />
        或点击此区域选择文件
      </div>
      <div id="fileInfo" class="muted">未选择文件</div>
      <div class="actions">
        <button id="uploadBtn" disabled>上传文件</button>
      </div>
      <div id="status" class="status">等待选择文件...</div>
    </div>
  </div>
  <script>
    (function () {
      const fileInput = document.getElementById('fileInput');
      const dropzone = document.getElementById('dropzone');
      const fileInfo = document.getElementById('fileInfo');
      const uploadBtn = document.getElementById('uploadBtn');
      const statusBox = document.getElementById('status');
      const mgmtKey = document.getElementById('mgmtKey');
      let selectedFile = null;

      function setStatus(msg) { statusBox.textContent = msg; }
      function updateFile(file) {
        selectedFile = file || null;
        if (selectedFile) {
          fileInfo.textContent = '已选择: ' + selectedFile.name + ' (' + selectedFile.size + ' bytes)';
          uploadBtn.disabled = false;
        } else {
          fileInfo.textContent = '未选择文件';
          uploadBtn.disabled = true;
        }
      }

      dropzone.addEventListener('click', () => fileInput.click());
      fileInput.addEventListener('change', () => updateFile(fileInput.files && fileInput.files[0]));
      dropzone.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.classList.add('dragover'); });
      dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
      dropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropzone.classList.remove('dragover');
        if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]) {
          updateFile(e.dataTransfer.files[0]);
        }
      });

      uploadBtn.addEventListener('click', async () => {
        const key = (mgmtKey.value || '').trim();
        if (!key) { setStatus('请先输入管理密钥。'); return; }
        if (!selectedFile) { setStatus('请先选择文件。'); return; }

        uploadBtn.disabled = true;
        setStatus('上传中...');
        try {
          const form = new FormData();
          form.append('file', selectedFile, selectedFile.name);

          const resp = await fetch('/v0/management/auth-files', {
            method: 'POST',
            headers: { 'X-Management-Key': key },
            body: form
          });
          const text = await resp.text();
          if (!resp.ok) {
            setStatus('上传失败 [' + resp.status + ']\\n' + text);
            return;
          }
          setStatus('上传成功\\n' + text);
        } catch (err) {
          setStatus('上传异常\\n' + (err && err.message ? err.message : String(err)));
        } finally {
          uploadBtn.disabled = !selectedFile;
        }
      });
    })();
  </script>
</body>
</html>`

func (s *Server) serveManagementUploadPage(c *gin.Context) {
	cfg := s.cfg
	if cfg == nil || cfg.RemoteManagement.DisableControlPanel {
		c.AbortWithStatus(http.StatusNotFound)
		return
	}
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, managementUploadPageHTML)
}
