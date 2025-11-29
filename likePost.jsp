<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.UUID, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    String postId = request.getParameter("post_id");

    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    
    if (postId == null || postId.trim().isEmpty()) {
        out.println("<script>history.back();</script>");
        return;
    }

    String referer = request.getHeader("Referer");
    if (referer == null || referer.isEmpty()) {
        referer = "main.jsp";
    }
    
    // [중요] 기존 앵커(#) 제거 (새로 붙이기 위해)
    if (referer.contains("#")) {
        referer = referer.substring(0, referer.indexOf("#"));
    }

    String msg = null;

    try {
        boolean already = false;
        String chkSql = "SELECT 1 FROM post_likes WHERE post_id = ? AND liker_id = ?";
        try (PreparedStatement ps = con.prepareStatement(chkSql)) {
            ps.setString(1, postId);
            ps.setString(2, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) already = true;
            }
        }

        boolean oldAuto = con.getAutoCommit();
        con.setAutoCommit(false);

        try {
            if (already) {
                // [UNLIKE]
                String delSql = "DELETE FROM post_likes WHERE post_id = ? AND liker_id = ?";
                try (PreparedStatement ps = con.prepareStatement(delSql)) {
                    ps.setString(1, postId);
                    ps.setString(2, currentUser);
                    ps.executeUpdate();
                }
                String downSql = "UPDATE posts SET num_of_likes = num_of_likes - 1 WHERE post_id = ?";
                try (PreparedStatement ps = con.prepareStatement(downSql)) {
                    ps.setString(1, postId);
                    ps.executeUpdate();
                }
            } else {
                // [LIKE] UUID 생성 로직 복구 완료!
                String likeId = "pl" + java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                String insSql = "INSERT INTO post_likes (l_id, post_id, liker_id) VALUES (?, ?, ?)";
                try (PreparedStatement ps = con.prepareStatement(insSql)) {
                    ps.setString(1, likeId);
                    ps.setString(2, postId);
                    ps.setString(3, currentUser);
                    ps.executeUpdate();
                }
                String upSql = "UPDATE posts SET num_of_likes = num_of_likes + 1 WHERE post_id = ?";
                try (PreparedStatement ps = con.prepareStatement(upSql)) {
                    ps.setString(1, postId);
                    ps.executeUpdate();
                }
            }
            con.commit();
            con.setAutoCommit(oldAuto);

        } catch (Exception inner) {
            con.rollback();
            con.setAutoCommit(true);
            throw inner;
        }

    } catch (Exception e) {
        e.printStackTrace();
        msg = "오류 발생";
    } finally {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
    }

    // [핵심] 처리가 끝나면 게시글 위치(#post-아이디)로 이동
    response.sendRedirect(referer + "#post-" + postId);
%>