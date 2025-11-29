<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.io.*, java.sql.*, java.util.UUID" %>
<%-- 톰캣 10(Jakarta) 표준 파일 업로드를 위한 import --%>
<%@ page import="jakarta.servlet.http.Part" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // 1. 파일 저장 경로 설정
    String saveFolder = "uploads";
    String realPath = application.getRealPath(saveFolder);
    
    File dir = new File(realPath);
    if (!dir.exists()) {
        dir.mkdirs();
    }

    String msg = null;
    String redirectUrl = "main.jsp";
    boolean ok = false;

    try {
        // 2. 데이터 받기 (Standard Servlet API 사용)
        // context.xml에서 allowCasualMultipartParsing="true"를 설정했으므로 getParameter 사용 가능
        String content = request.getParameter("content");
        
        // 파일 받기
        Part filePart = request.getPart("postImage"); // form의 input name="postImage"
        String fileName = null;

        // 파일이 실제로 업로드되었는지 확인
        if (filePart != null && filePart.getSize() > 0) {
            // 파일명 추출 (경로 찌꺼기 제거)
            fileName = filePart.getSubmittedFileName();
            
            // 파일 저장 (InputStream -> FileOutputStream 복사 방식)
            // (톰캣 10의 part.write()는 설정이 복잡하므로 직접 스트림 복사가 안전합니다)
            InputStream is = filePart.getInputStream();
            File targetFile = new File(realPath + File.separator + fileName);
            FileOutputStream fos = new FileOutputStream(targetFile);
            
            byte[] buffer = new byte[1024];
            int bytesRead;
            while ((bytesRead = is.read(buffer)) != -1) {
                fos.write(buffer, 0, bytesRead);
            }
            fos.close();
            is.close();
        }

        if (content == null) content = "";
        content = content.trim();

        // 3. DB에 저장
        String postId = "p" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);

        String sql = "INSERT INTO posts (post_id, writer_id, content, img_file, num_of_likes, created_at) VALUES (?, ?, ?, ?, 0, NOW())";
        
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, postId);
            ps.setString(2, currentUser);
            ps.setString(3, content);
            ps.setString(4, fileName); // 파일명 (없으면 null 들어감)
            ps.executeUpdate();
        }

        ok = true;

    } catch (Exception e) {
        e.printStackTrace();
        msg = "업로드 실패: " + e.getMessage();
    } finally {
        if (con != null) try { con.close(); } catch(Exception e) {}
    }

    if (ok) {
        response.sendRedirect(redirectUrl);
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>업로드 오류</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
</head>
<body>
<div class="app-shell">
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
        </div>
    </header>
    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">오류 발생</div>
            <div class="msg msg-err"><%= (msg!=null)?msg:"알 수 없는 오류" %></div>
            <div style="margin-top:10px; color:#536471; font-size:13px;">
                혹시 context.xml 설정을 변경하셨나요?<br>
                allowCasualMultipartParsing="true" 설정이 필요합니다.
            </div>
            <a href="main.jsp" class="btn-primary" style="display:block; text-align:center; margin-top:10px;">돌아가기</a>
        </div>
    </div>
</div>
</body>
</html>