<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
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

    String commentId = request.getParameter("comment_id");
    String postId = request.getParameter("post_id");

    if (commentId == null) commentId = "";
    if (postId == null) postId = "";

    commentId = commentId.trim();
    postId = postId.trim();

    // 기본 리다이렉트는 해당 게시글 상세 페이지
    String redirectUrl;
    if (postId.isEmpty()) {
        redirectUrl = "main.jsp";
    } else {
        redirectUrl = "postDetail.jsp?post_id=" + postId;
    }

    String msg = null;
    boolean ok = false;

    if (commentId.isEmpty()) {
        msg = "어느 댓글에 좋아요를 눌러야 할지 알 수 없습니다";
    } else {
        try {
            boolean oldAuto = con.getAutoCommit();
            con.setAutoCommit(false);
            try {
                // 이미 좋아요 했는지 확인
                boolean already = false;
                String chkSql =
                    "SELECT 1 FROM comment_likes " +
                    "WHERE comment_id = ? AND liker_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chkSql)) {
                    ps.setString(1, commentId);
                    ps.setString(2, currentUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            already = true;
                        }
                    }
                }

                if (!already) {
                    // 좋아요 기록 insert
                    String likeId = "cl" + java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 10);

                    String insSql =
                        "INSERT INTO comment_likes (l_id, comment_id, liker_id) " +
                        "VALUES (?, ?, ?)";
                    try (PreparedStatement ps = con.prepareStatement(insSql)) {
                        ps.setString(1, likeId);
                        ps.setString(2, commentId);
                        ps.setString(3, currentUser);
                        ps.executeUpdate();
                    }

                    // 댓글 좋아요 수 증가
                    String upSql =
                        "UPDATE comments " +
                        "SET num_of_likes = num_of_likes + 1 " +
                        "WHERE comment_id = ?";
                    try (PreparedStatement ps = con.prepareStatement(upSql)) {
                        ps.setString(1, commentId);
                        int n = ps.executeUpdate();
                        if (n == 0) {
                            throw new Exception("해당 comment_id를 가진 댓글이 없습니다");
                        }
                    }
                }

                con.commit();
                con.setAutoCommit(oldAuto);
                ok = true;
            } catch (Exception inner) {
                con.rollback();
                throw inner;
            }
        } catch (Exception e) {
            e.printStackTrace();
            msg = "댓글 좋아요를 처리하는 중 오류가 발생했어요";
        } finally {
            if (con != null) {
                try { con.close(); } catch (Exception ignore) {}
            }
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
    <title>댓글 좋아요 오류  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">댓글 좋아요 오류</div>
        </div>
    </header>

    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">댓글 좋아요를 처리하지 못했습니다</div>
            <div class="auth-sub">
                다시 시도해 보거나, 아래 버튼을 눌러 게시글 화면으로 돌아갈 수 있습니다
            </div>

            <%
                if (msg != null) {
            %>
                <div class="msg msg-err"><%= msg %></div>
            <%
                }
            %>

            <a href="<%= redirectUrl %>" class="btn-primary" style="width:100%; display:inline-block; text-align:center; margin-top:8px;">
                게시글로 돌아가기
            </a>
        </div>
    </div>
</div>
</body>
</html>
