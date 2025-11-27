<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.*, java.util.LinkedList, java.util.Queue" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String commentId = request.getParameter("comment_id");
    String postId    = request.getParameter("post_id");

    if (commentId != null) commentId = commentId.trim();
    if (postId    != null) postId    = postId.trim();

    if (commentId == null || commentId.isEmpty() ||
        postId == null || postId.isEmpty()) {
        response.sendRedirect("main.jsp");
        return;
    }

    String writerId = null;

    try {
        // 댓글 작성자 확인
        String sql = "SELECT writer_id FROM comments WHERE comment_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, commentId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    writerId = rs.getString("writer_id");
                }
            }
        }

        if (writerId == null || !currentUser.equals(writerId)) {
            // 내 댓글이 아니면 삭제 불가
            response.sendRedirect("postDetail.jsp?post_id=" + postId);
            return;
        }

        con.setAutoCommit(false);

        // BFS 로 이 댓글과 모든 대댓글 삭제
        Queue<String> q = new LinkedList<String>();
        q.add(commentId);

        while (!q.isEmpty()) {
            String cid = q.poll();

            // cid 에 달린 자식 댓글들 큐에 추가
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT comment_id FROM comments WHERE parent_id = ?")) {
                ps.setString(1, cid);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        q.add(rs.getString(1));
                    }
                }
            }

            // 좋아요 삭제
            try (PreparedStatement ps = con.prepareStatement(
                    "DELETE FROM comment_likes WHERE comment_id = ?")) {
                ps.setString(1, cid);
                ps.executeUpdate();
            }

            // 댓글 삭제
            try (PreparedStatement ps = con.prepareStatement(
                    "DELETE FROM comments WHERE comment_id = ?")) {
                ps.setString(1, cid);
                ps.executeUpdate();
            }
        }

        con.commit();
    } catch (Exception e) {
        e.printStackTrace();
        try { con.rollback(); } catch (Exception ignore) {}
    } finally {
        try { con.setAutoCommit(true); } catch (Exception ignore) {}
        if (con != null) try { con.close(); } catch (Exception ignore) {}
    }

    response.sendRedirect("postDetail.jsp?post_id=" + postId);
%>
