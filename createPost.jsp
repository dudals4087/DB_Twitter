<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // 세션 정보
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    // 로그인 안 되어 있으면 로그인 페이지로
    if (currentUser == null) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    // POST가 아니면 메인으로
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("main.jsp");
        return;
    }

    String content = request.getParameter("content");
    if (content == null) content = "";
    content = content.trim();

    String redirectUrl = "main.jsp";

    String msg = null;
    boolean ok = false;

    try {
        String postId = "p" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);

        String sql =
            "INSERT INTO posts (post_id, content, writer_id, num_of_likes) " +
            "VALUES (?, ?, ?, 0)";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, postId);
            ps.setString(2, content);
            ps.setString(3, currentUser);
            ps.executeUpdate();
        }

        ok = true;
    } catch (Exception e) {
        e.printStackTrace();
        msg = "게시글을 저장하는 중 오류가 발생했어요";
    } finally {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
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
    <title>게시글 작성 오류  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">게시글 작성 오류</div>
        </div>
    </header>

    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">게시글을 저장하지 못했습니다</div>
            <div class="auth-sub">
                다시 시도해 보거나, 아래 버튼을 눌러 메인 화면으로 돌아갈 수 있습니다
            </div>

            <%
                if (msg != null) {
            %>
                <div class="msg msg-err"><%= msg %></div>
            <%
                }
            %>

            <a href="<%= redirectUrl %>" class="btn-primary" style="width:100%; display:inline-block; text-align:center; margin-top:8px;">
                메인으로 돌아가기
            </a>
        </div>
    </div>
</div>
</body>
</html>
