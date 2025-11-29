<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    String postId = request.getParameter("post_id");

    // 1. 권한 체크 (로그인 안 했거나 POST가 아니면 튕김)
    if (currentUser == null) {
        out.println("<script>alert('로그인이 필요합니다.'); location.href='login.jsp';</script>");
        return;
    }
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
        response.sendRedirect("main.jsp");
        return;
    }

    if (postId == null || postId.trim().isEmpty()) {
        out.println("<script>history.back();</script>");
        return;
    }

    String msg = null;

    try {
        boolean oldAuto = con.getAutoCommit();
        con.setAutoCommit(false); // 트랜잭션 시작

        try {
            // 2. 종속 데이터 삭제 (댓글, 좋아요 기록)
            
            // 2-1. 댓글 (comments 테이블) 삭제
            String delCmtSql = "DELETE FROM comments WHERE post_id = ?";
            try (PreparedStatement ps = con.prepareStatement(delCmtSql)) {
                ps.setString(1, postId);
                ps.executeUpdate();
            }

            // 2-2. 좋아요 기록 (post_likes 테이블) 삭제
            String delLikeSql = "DELETE FROM post_likes WHERE post_id = ?";
            try (PreparedStatement ps = con.prepareStatement(delLikeSql)) {
                ps.setString(1, postId);
                ps.executeUpdate();
            }

            // 3. 게시글 본문 삭제 (보안: 본인 글인지 확인 후 삭제)
            String delPostSql = "DELETE FROM posts WHERE post_id = ? AND writer_id = ?";
            try (PreparedStatement ps = con.prepareStatement(delPostSql)) {
                ps.setString(1, postId);
                ps.setString(2, currentUser);
                int deletedRows = ps.executeUpdate();
                
                if (deletedRows == 0) {
                    throw new Exception("해당 게시글의 작성자가 아니거나 게시글이 이미 삭제되었습니다.");
                }
            }

            con.commit();
            con.setAutoCommit(oldAuto);
            msg = "게시글이 성공적으로 삭제되었습니다.";

        } catch (Exception inner) {
            con.rollback(); // 오류 시 롤백
            con.setAutoCommit(true);
            throw inner;
        }

    } catch (Exception e) {
        e.printStackTrace();
        msg = "게시글 삭제 중 오류가 발생했습니다: " + e.getMessage();
    } finally {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
    }

    // 삭제 후 메인 페이지로 이동
    out.println("<script>alert('" + msg + "'); location.href='main.jsp';</script>");
%>